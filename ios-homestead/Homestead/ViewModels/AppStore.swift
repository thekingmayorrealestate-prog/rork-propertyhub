import Foundation
import Observation

enum StoreError: LocalizedError {
    case invalidCredentials
    case suspended
    case emailTaken
    case invalidEmail
    case weakPassword
    case missingName
    case notSignedIn
    case datesUnavailable
    case invalidDates
    case ownListing
    case roomsUnavailable(Int)
    case tooManyGuests(Int)
    case roomClosed
    case reviewNotAllowed

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "That email and password don't match an account."
        case .suspended: "This account has been suspended. Contact support@homestead.ng."
        case .emailTaken: "An account with this email already exists."
        case .invalidEmail: "Please enter a valid email address."
        case .weakPassword: "Use at least 6 characters for your password."
        case .missingName: "Please enter your full name."
        case .notSignedIn: "Please sign in to continue."
        case .datesUnavailable: "Those dates are no longer available."
        case .invalidDates: "Check-out must be after check-in."
        case .ownListing: "You can't book your own listing."
        case .roomsUnavailable(let left): left == 0 ? "This room type is sold out for those dates." : "Only \(left) room\(left == 1 ? " is" : "s are") left for those dates."
        case .tooManyGuests(let max): "These rooms fit up to \(max) guests. Add another room or pick a larger room type."
        case .roomClosed: "This room type isn't taking reservations right now."
        case .reviewNotAllowed: "You can review a place after your stay."
        }
    }
}

/// Platform-wide counts shown on the admin dashboard.
struct AdminStats {
    var users: Int
    var agents: Int
    var approvedAgents: Int
    var hotelOwners: Int
    var pendingHotelOwners: Int
    var hotelReservations: Int
    var shortletBookings: Int
    var rentalInquiries: Int
    var saleInquiries: Int
    var activeListings: Int
    var pendingListings: Int
    var bookingRequests: Int
    var openReports: Int
    var revenue: Int
}

/// Single source of truth for accounts, listings, bookings, payments, messages and notifications.
@Observable
final class AppStore {
    private(set) var data: AppData
    private(set) var currentUserID: UUID?

    private let sessionKey = "homestead.session.userID"

    init() {
        if let saved = PersistenceService.load(), saved.version == SeedData.version {
            data = saved
        } else {
            data = SeedData.make()
            PersistenceService.save(data)
        }
        if let raw = UserDefaults.standard.string(forKey: "homestead.session.userID"),
           let id = UUID(uuidString: raw),
           data.accounts.contains(where: { $0.id == id && !$0.isSuspended }) {
            currentUserID = id
        }
    }

    private func save() {
        PersistenceService.save(data)
    }

    // MARK: - Session

    var currentUser: Account? {
        guard let currentUserID else { return nil }
        return data.accounts.first { $0.id == currentUserID }
    }

    var isSignedIn: Bool { currentUser != nil }
    var isAdmin: Bool { currentUser?.role == .admin }
    var isAgent: Bool { currentUser?.role == .agent }
    var isHotelOwner: Bool { currentUser?.role == .hotelOwner }
    var isProvider: Bool { currentUser?.role.isProvider ?? false }

    func signIn(email: String, password: String) throws {
        let normalized = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard let account = data.accounts.first(where: { $0.email.lowercased() == normalized }),
              PasswordHasher.hash(password, salt: account.salt) == account.passwordHash else {
            throw StoreError.invalidCredentials
        }
        guard !account.isSuspended else { throw StoreError.suspended }
        setSession(account.id)
    }

    func signUp(name: String, email: String, phone: String, password: String, role: UserRole, agencyName: String?) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let normalized = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedName.isEmpty else { throw StoreError.missingName }
        guard normalized.contains("@"), normalized.contains("."), normalized.count >= 5 else { throw StoreError.invalidEmail }
        guard password.count >= 6 else { throw StoreError.weakPassword }
        guard !data.accounts.contains(where: { $0.email.lowercased() == normalized }) else { throw StoreError.emailTaken }

        let salt = PasswordHasher.makeSalt()
        let account = Account(
            id: UUID(), name: trimmedName, email: normalized, phone: phone, passwordHash: PasswordHasher.hash(password, salt: salt),
            salt: salt, role: role, agencyName: role.isProvider ? agencyName : nil, bio: "", avatarName: nil,
            isVerified: false, isSuspended: false, favoriteIDs: [], createdAt: Date()
        )
        data.accounts.append(account)
        if role == .agent {
            notifyAdmins(.system, "Agent verification", "\(trimmedName) registered as an agent/landlord.")
            notify(account.id, .system, "Welcome to Homestead", "Your agent profile is awaiting verification. You can start adding listings now.")
        } else if role == .hotelOwner {
            notifyAdmins(.system, "Hotel-owner application", "\(trimmedName) applied to list \(agencyName ?? "a hotel").")
            notify(account.id, .system, "Application received", "We're reviewing your hotel-owner application. You can add your hotel and rooms now — they go live after approval.")
        } else {
            notify(account.id, .system, "Welcome to Homestead", "Save homes you love and book shortlets in a few taps.")
        }
        save()
        setSession(account.id)
    }

    func signOut() {
        currentUserID = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    private func setSession(_ id: UUID) {
        currentUserID = id
        UserDefaults.standard.set(id.uuidString, forKey: sessionKey)
    }

    func updateProfile(name: String, phone: String, bio: String, agencyName: String?) {
        guard let idx = currentIndex else { return }
        data.accounts[idx].name = name.trimmingCharacters(in: .whitespaces)
        data.accounts[idx].phone = phone
        data.accounts[idx].bio = bio
        if data.accounts[idx].role.isProvider { data.accounts[idx].agencyName = agencyName }
        save()
    }

    func becomeAgent(agencyName: String, phone: String) {
        guard let idx = currentIndex else { return }
        data.accounts[idx].role = .agent
        data.accounts[idx].agencyName = agencyName
        data.accounts[idx].phone = phone
        data.accounts[idx].isVerified = false
        notifyAdmins(.system, "Agent verification", "\(data.accounts[idx].name) upgraded to an agent/landlord account.")
        notify(data.accounts[idx].id, .system, "Agent profile created", "We'll verify your profile shortly. Listings are reviewed before going live.")
        save()
    }

    func becomeHotelOwner(hotelName: String, phone: String) {
        guard let idx = currentIndex else { return }
        data.accounts[idx].role = .hotelOwner
        data.accounts[idx].agencyName = hotelName
        data.accounts[idx].phone = phone
        data.accounts[idx].isVerified = false
        notifyAdmins(.system, "Hotel-owner application", "\(data.accounts[idx].name) applied to list \(hotelName).")
        notify(data.accounts[idx].id, .system, "Application received", "We're reviewing your hotel-owner application. Add your hotel and rooms while you wait.")
        save()
    }

    private var currentIndex: Int? {
        guard let currentUserID else { return nil }
        return data.accounts.firstIndex { $0.id == currentUserID }
    }

    // MARK: - Lookups

    func account(_ id: UUID) -> Account? { data.accounts.first { $0.id == id } }
    func listing(_ id: UUID) -> Listing? { data.listings.first { $0.id == id } }
    func booking(_ id: UUID) -> Booking? { data.bookings.first { $0.id == id } }
    func payment(_ id: UUID) -> Payment? { data.payments.first { $0.id == id } }
    func thread(_ id: UUID) -> ChatThread? { data.threads.first { $0.id == id } }

    var liveListings: [Listing] { data.listings.filter { $0.status == .live } }

    func liveListings(in category: ListingCategory) -> [Listing] {
        liveListings.filter { $0.category == category }.sorted { $0.createdAt > $1.createdAt }
    }

    var featuredListings: [Listing] {
        liveListings.filter { $0.category != .shortlet && $0.isFeatured }.sorted { $0.createdAt > $1.createdAt }
    }

    var popularShortlets: [Listing] {
        liveListings(in: .shortlet).sorted { $0.rating > $1.rating }
    }

    var topHotels: [Listing] {
        liveListings(in: .hotel).sorted { ($0.isFeatured ? 1 : 0, $0.rating) > ($1.isFeatured ? 1 : 0, $1.rating) }
    }

    func isAgentVerified(_ listing: Listing) -> Bool {
        account(listing.agentID)?.isVerified ?? false
    }

    func isOwner(_ listing: Listing) -> Bool { listing.agentID == currentUserID }

    // MARK: - Favorites

    func isFavorite(_ id: UUID) -> Bool { currentUser?.favoriteIDs.contains(id) ?? false }

    var favoriteListings: [Listing] {
        guard let ids = currentUser?.favoriteIDs else { return [] }
        return ids.compactMap { listing($0) }
    }

    func toggleFavorite(_ id: UUID) {
        guard let idx = currentIndex else { return }
        if let pos = data.accounts[idx].favoriteIDs.firstIndex(of: id) {
            data.accounts[idx].favoriteIDs.remove(at: pos)
        } else {
            data.accounts[idx].favoriteIDs.insert(id, at: 0)
        }
        save()
    }

    // MARK: - Search

    func search(_ f: SearchFilters) -> [Listing] {
        var results = liveListings
        if let category = f.category { results = results.filter { $0.category == category } }
        let q = f.query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            results = results.filter {
                $0.title.localizedStandardContains(q) || $0.area.localizedStandardContains(q) ||
                $0.city.localizedStandardContains(q) || $0.propertyType.title.localizedStandardContains(q)
            }
        }
        if let city = f.city { results = results.filter { $0.city == city } }
        if !f.types.isEmpty { results = results.filter { f.types.contains($0.propertyType) } }
        if f.minBedrooms > 0 { results = results.filter { $0.isHotel || $0.bedrooms >= f.minBedrooms } }
        if let kind = f.roomKind {
            results = results.filter { !$0.isHotel || ($0.hotel?.openRooms.contains { $0.kind == kind } ?? false) }
        }
        if let checkIn = f.checkIn, let checkOut = f.checkOut, checkOut > checkIn {
            results = results.filter { listing in
                switch listing.category {
                case .shortlet: return listing.sleeps >= f.guests && isAvailable(listingID: listing.id, from: checkIn, to: checkOut)
                case .hotel: return !matchingRooms(listing, filters: f).isEmpty
                default: return true
                }
            }
        } else if f.guests > 1 {
            results = results.filter { listing in
                switch listing.category {
                case .shortlet: return listing.sleeps >= f.guests
                case .hotel: return (listing.hotel?.openRooms.contains { $0.capacity * f.rooms >= f.guests } ?? false)
                default: return true
                }
            }
        }
        if let min = f.minPrice { results = results.filter { $0.price >= min } }
        if let max = f.maxPrice { results = results.filter { $0.price <= max } }
        if !f.facilities.isEmpty { results = results.filter { Set($0.facilities).isSuperset(of: f.facilities) } }
        if f.verifiedOnly { results = results.filter { isAgentVerified($0) } }

        switch f.sort {
        case .recommended: results.sort { ($0.isFeatured ? 1 : 0, $0.totalViews) > ($1.isFeatured ? 1 : 0, $1.totalViews) }
        case .newest: results.sort { $0.createdAt > $1.createdAt }
        case .priceLow: results.sort { $0.price < $1.price }
        case .priceHigh: results.sort { $0.price > $1.price }
        case .rating: results.sort { $0.rating > $1.rating }
        }
        return results
    }

    // MARK: - Hotels

    /// Open room types that fit the filters' guests, rooms, room kind and dates.
    func matchingRooms(_ listing: Listing, filters f: SearchFilters) -> [RoomType] {
        guard let rooms = listing.hotel?.openRooms else { return [] }
        return rooms.filter { room in
            if let kind = f.roomKind, room.kind != kind { return false }
            if room.capacity * f.rooms < f.guests { return false }
            if let checkIn = f.checkIn, let checkOut = f.checkOut, checkOut > checkIn {
                return roomsAvailable(listing: listing, roomTypeID: room.id, from: checkIn, to: checkOut) >= f.rooms
            }
            return true
        }
    }

    /// Rooms of a type still free on every night of the stay (pending and confirmed reservations hold inventory).
    func roomsAvailable(listing: Listing, roomTypeID: UUID, from: Date, to: Date, excluding bookingID: UUID? = nil) -> Int {
        guard let room = listing.room(roomTypeID), room.isOpen else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.startOfDay(for: to)
        guard end > start else { return room.totalRooms }
        let holds = data.bookings.filter {
            $0.listingID == listing.id && $0.roomTypeID == roomTypeID && $0.id != bookingID &&
                ($0.status == .pending || $0.status == .confirmed) && $0.checkIn != nil && $0.checkOut != nil
        }
        var maxBooked = 0
        var night = start
        while night < end {
            let booked = holds.reduce(0) { sum, b in
                let bIn = cal.startOfDay(for: b.checkIn ?? night)
                let bOut = cal.startOfDay(for: b.checkOut ?? night)
                return bIn <= night && night < bOut ? sum + b.rooms : sum
            }
            maxBooked = max(maxBooked, booked)
            night = cal.date(byAdding: .day, value: 1, to: night) ?? end
        }
        return max(room.totalRooms - maxBooked, 0)
    }

    /// Rooms booked on a given night across all room types of a hotel.
    func roomsBooked(listing: Listing, on date: Date) -> Int {
        let cal = Calendar.current
        let night = cal.startOfDay(for: date)
        return data.bookings.filter { $0.listingID == listing.id && $0.kind == .hotelReservation && ($0.status == .confirmed || $0.status == .pending) }
            .reduce(0) { sum, b in
                guard let bIn = b.checkIn, let bOut = b.checkOut else { return sum }
                return cal.startOfDay(for: bIn) <= night && night < cal.startOfDay(for: bOut) ? sum + b.rooms : sum
            }
    }

    /// Reserves hotel rooms after a final availability check, records payment and confirms instantly.
    @discardableResult
    func reserveHotel(listing: Listing, roomTypeID: UUID, checkIn: Date, checkOut: Date, guests: Int, rooms: Int, message: String, method: PaymentMethod, cardLast4: String?) throws -> Booking {
        guard let user = currentUser else { throw StoreError.notSignedIn }
        guard listing.agentID != user.id else { throw StoreError.ownListing }
        guard checkOut > checkIn else { throw StoreError.invalidDates }
        guard let fresh = self.listing(listing.id), let room = fresh.room(roomTypeID) else { throw StoreError.roomClosed }
        guard room.isOpen, fresh.status == .live else { throw StoreError.roomClosed }
        guard guests <= room.capacity * rooms else { throw StoreError.tooManyGuests(room.capacity * rooms) }
        let left = roomsAvailable(listing: fresh, roomTypeID: roomTypeID, from: checkIn, to: checkOut)
        guard left >= rooms else { throw StoreError.roomsUnavailable(left) }

        let booking = Booking(
            id: UUID(), listingID: fresh.id, userID: user.id, agentID: fresh.agentID, category: .hotel,
            kind: .hotelReservation, checkIn: checkIn, checkOut: checkOut, guests: guests, viewingDate: nil,
            message: message, status: .confirmed, agentNote: nil, createdAt: Date(), roomTypeID: roomTypeID, rooms: rooms
        )
        let quote = room.quote(nights: booking.nights, rooms: rooms)
        data.bookings.append(booking)
        let payment = Payment(
            id: UUID(), bookingID: booking.id, userID: user.id, listingID: fresh.id, amount: quote.subtotal,
            serviceFee: quote.fee, method: method, status: .paid, reference: makeReference(), cardLast4: cardLast4, createdAt: Date()
        )
        data.payments.append(payment)
        notify(user.id, .booking, "Reservation confirmed", "\(fresh.title) · \(room.name), \(booking.dateSummary). Confirmation \(booking.confirmationCode).")
        notify(user.id, .payment, "Payment successful", "\(Money.naira(payment.total)) paid. Receipt \(payment.reference).")
        notify(fresh.agentID, .booking, "New reservation", "\(user.shortName) booked \(rooms) × \(room.name) for \(booking.nights) night\(booking.nights == 1 ? "" : "s").")
        save()
        return booking
    }

    /// Refund a guest would receive if they cancelled now, according to the hotel's policy.
    func refundPreview(for booking: Booking) -> (amount: Int, fraction: Double) {
        let paid = payments(for: booking.id).filter { $0.status == .paid }.reduce(0) { $0 + $1.total }
        let fraction: Double
        if booking.kind == .hotelReservation, let policy = listing(booking.listingID)?.hotel?.policy, let checkIn = booking.checkIn {
            fraction = policy.refundFraction(hoursBefore: checkIn.timeIntervalSinceNow / 3600)
        } else {
            fraction = 1
        }
        return (Int((Double(paid) * fraction).rounded()), fraction)
    }

    func addRoom(_ room: RoomType, to listingID: UUID) {
        guard let idx = data.listings.firstIndex(where: { $0.id == listingID }) else { return }
        data.listings[idx].hotel?.rooms.append(room)
        syncHotelPrice(idx)
        save()
    }

    func updateRoom(_ room: RoomType, in listingID: UUID) {
        guard let idx = data.listings.firstIndex(where: { $0.id == listingID }),
              let rIdx = data.listings[idx].hotel?.rooms.firstIndex(where: { $0.id == room.id }) else { return }
        data.listings[idx].hotel?.rooms[rIdx] = room
        syncHotelPrice(idx)
        save()
    }

    func deleteRoom(_ roomID: UUID, from listingID: UUID) {
        guard let idx = data.listings.firstIndex(where: { $0.id == listingID }) else { return }
        data.listings[idx].hotel?.rooms.removeAll { $0.id == roomID }
        syncHotelPrice(idx)
        save()
    }

    func setRoomOpen(_ roomID: UUID, in listingID: UUID, open: Bool) {
        guard let idx = data.listings.firstIndex(where: { $0.id == listingID }),
              let rIdx = data.listings[idx].hotel?.rooms.firstIndex(where: { $0.id == roomID }) else { return }
        data.listings[idx].hotel?.rooms[rIdx].isOpen = open
        syncHotelPrice(idx)
        save()
    }

    private func syncHotelPrice(_ idx: Int) {
        guard let hotel = data.listings[idx].hotel else { return }
        data.listings[idx].price = hotel.lowestRate
        data.listings[idx].sleeps = hotel.maxCapacity
    }

    // MARK: - Reviews

    func reviews(for listingID: UUID) -> [Review] {
        data.reviews.filter { $0.listingID == listingID }.sorted { $0.createdAt > $1.createdAt }
    }

    /// A signed-in guest can review a place once, after a completed (or checked-out) stay.
    func canReview(_ listingID: UUID) -> Bool {
        guard let id = currentUserID else { return false }
        guard !data.reviews.contains(where: { $0.listingID == listingID && $0.userID == id }) else { return false }
        return data.bookings.contains { b in
            b.listingID == listingID && b.userID == id && b.kind.isStay &&
                (b.status == .completed || (b.status == .confirmed && (b.checkOut ?? .distantFuture) < Date()))
        }
    }

    func addReview(listingID: UUID, rating: Int, text: String) throws {
        guard let user = currentUser else { throw StoreError.notSignedIn }
        guard canReview(listingID), let idx = data.listings.firstIndex(where: { $0.id == listingID }) else { throw StoreError.reviewNotAllowed }
        let clamped = min(max(rating, 1), 5)
        data.reviews.append(Review(id: UUID(), listingID: listingID, userID: user.id, authorName: user.shortName, rating: clamped, text: text.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: Date()))
        let l = data.listings[idx]
        let total = l.rating * Double(l.reviewCount) + Double(clamped)
        data.listings[idx].reviewCount += 1
        data.listings[idx].rating = total / Double(data.listings[idx].reviewCount)
        notify(l.agentID, .listing, "New \(clamped)★ review", "\(user.shortName) reviewed \(l.title).")
        save()
    }

    // MARK: - Bookings & inquiries

    var myBookings: [Booking] {
        data.bookings.filter { $0.userID == currentUserID }.sorted { $0.createdAt > $1.createdAt }
    }

    var myPayments: [Payment] {
        data.payments.filter { $0.userID == currentUserID }.sorted { $0.createdAt > $1.createdAt }
    }

    var incomingRequests: [Booking] {
        data.bookings.filter { $0.agentID == currentUserID }.sorted { $0.createdAt > $1.createdAt }
    }

    func payments(for bookingID: UUID) -> [Payment] {
        data.payments.filter { $0.bookingID == bookingID }
    }

    func bookings(for listingID: UUID) -> [Booking] {
        data.bookings.filter { $0.listingID == listingID }
    }

    func isAvailable(listingID: UUID, from: Date, to: Date) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.startOfDay(for: to)
        return !data.bookings.contains { b in
            guard b.listingID == listingID, b.kind == .shortletBooking,
                  b.status == .pending || b.status == .confirmed,
                  let bIn = b.checkIn, let bOut = b.checkOut else { return false }
            return cal.startOfDay(for: bIn) < end && start < cal.startOfDay(for: bOut)
        }
    }

    /// Creates a shortlet booking request and records the secure payment for it.
    @discardableResult
    func bookShortlet(listing: Listing, checkIn: Date, checkOut: Date, guests: Int, message: String, method: PaymentMethod, cardLast4: String?) throws -> Booking {
        guard let user = currentUser else { throw StoreError.notSignedIn }
        guard listing.agentID != user.id else { throw StoreError.ownListing }
        guard checkOut > checkIn else { throw StoreError.invalidDates }
        guard isAvailable(listingID: listing.id, from: checkIn, to: checkOut) else { throw StoreError.datesUnavailable }

        let booking = Booking(
            id: UUID(), listingID: listing.id, userID: user.id, agentID: listing.agentID, category: .shortlet,
            kind: .shortletBooking, checkIn: checkIn, checkOut: checkOut, guests: guests, viewingDate: nil,
            message: message, status: .pending, agentNote: nil, createdAt: Date()
        )
        let quote = listing.quote(nights: booking.nights)
        data.bookings.append(booking)
        data.payments.append(Payment(
            id: UUID(), bookingID: booking.id, userID: user.id, listingID: listing.id, amount: quote.subtotal,
            serviceFee: quote.fee, method: method, status: .paid, reference: makeReference(), cardLast4: cardLast4, createdAt: Date()
        ))
        notify(user.id, .payment, "Payment received", "\(Money.naira(quote.total)) for \(listing.title). Awaiting host confirmation.")
        notify(listing.agentID, .booking, "New booking request", "\(user.shortName) requested \(booking.nights) night\(booking.nights == 1 ? "" : "s") at \(listing.title).")
        save()
        return booking
    }

    @discardableResult
    func submitInquiry(listing: Listing, kind: RequestKind, message: String, viewingDate: Date?) throws -> Booking {
        guard let user = currentUser else { throw StoreError.notSignedIn }
        guard listing.agentID != user.id else { throw StoreError.ownListing }
        let booking = Booking(
            id: UUID(), listingID: listing.id, userID: user.id, agentID: listing.agentID, category: listing.category,
            kind: kind, checkIn: nil, checkOut: nil, guests: 1, viewingDate: kind == .viewing ? viewingDate : nil,
            message: message, status: .pending, agentNote: nil, createdAt: Date()
        )
        data.bookings.append(booking)
        let action = kind == .viewing ? "wants a viewing of" : "sent an inquiry about"
        notify(listing.agentID, .inquiry, kind.title, "\(user.shortName) \(action) \(listing.title).")
        notify(user.id, .inquiry, "Request sent", "We've sent your \(kind.title.lowercased()) for \(listing.title) to the agent.")
        save()
        return booking
    }

    /// Agent accepts or declines a request; declined paid bookings are refunded.
    func respond(to bookingID: UUID, accept: Bool, note: String?) {
        guard let idx = data.bookings.firstIndex(where: { $0.id == bookingID }) else { return }
        let booking = data.bookings[idx]
        let title = listing(booking.listingID)?.title ?? "your listing"
        if accept {
            data.bookings[idx].status = booking.kind == .viewing ? .viewingScheduled : .confirmed
        } else {
            data.bookings[idx].status = .declined
            refundPayments(for: bookingID)
        }
        if let note, !note.trimmingCharacters(in: .whitespaces).isEmpty { data.bookings[idx].agentNote = note }
        let headline: String
        switch (accept, booking.kind) {
        case (true, .viewing): headline = "Viewing scheduled"
        case (true, .shortletBooking), (true, .hotelReservation): headline = "Booking confirmed"
        case (true, _): headline = "Inquiry accepted"
        case (false, .hotelReservation): headline = "Reservation cancelled by hotel"
        case (false, _): headline = "Request declined"
        }
        let body = booking.kind == .hotelReservation && !accept
            ? "\(title) cancelled reservation \(booking.confirmationCode). You've been refunded in full."
            : "\(title): \(accept ? "the agent accepted your request." : "the agent couldn't accept this request.")"
        notify(booking.userID, .booking, headline, body)
        save()
    }

    /// Guest cancellation. Hotel reservations are refunded according to the hotel's cancellation policy.
    func cancelBooking(_ bookingID: UUID) {
        guard let idx = data.bookings.firstIndex(where: { $0.id == bookingID }) else { return }
        let fraction = refundPreview(for: data.bookings[idx]).fraction
        data.bookings[idx].status = .cancelled
        refundPayments(for: bookingID, fraction: fraction)
        let b = data.bookings[idx]
        let title = listing(b.listingID)?.title ?? "a listing"
        notify(b.agentID, .booking, "Request cancelled", "\(account(b.userID)?.shortName ?? "A user") cancelled their request for \(title).")
        save()
    }

    func markCompleted(_ bookingID: UUID) {
        guard let idx = data.bookings.firstIndex(where: { $0.id == bookingID }) else { return }
        data.bookings[idx].status = .completed
        save()
    }

    @discardableResult
    func payForBooking(_ bookingID: UUID, amount: Int, method: PaymentMethod, cardLast4: String?) -> Payment? {
        guard let b = booking(bookingID), let user = currentUser else { return nil }
        let fee = Int((Double(amount) * 0.015).rounded())
        let payment = Payment(
            id: UUID(), bookingID: bookingID, userID: user.id, listingID: b.listingID, amount: amount, serviceFee: fee,
            method: method, status: .paid, reference: makeReference(), cardLast4: cardLast4, createdAt: Date()
        )
        data.payments.append(payment)
        let title = listing(b.listingID)?.title ?? "listing"
        notify(user.id, .payment, "Payment successful", "\(Money.naira(payment.total)) paid for \(title). Receipt \(payment.reference).")
        notify(b.agentID, .payment, "Payment received", "\(user.shortName) paid \(Money.naira(amount)) for \(title).")
        save()
        return payment
    }

    private func refundPayments(for bookingID: UUID, fraction: Double = 1) {
        for i in data.payments.indices where data.payments[i].bookingID == bookingID && data.payments[i].status == .paid {
            let amount = Int((Double(data.payments[i].total) * fraction).rounded())
            guard amount > 0 else {
                notify(data.payments[i].userID, .payment, "No refund due", "Receipt \(data.payments[i].reference) is non-refundable under the cancellation policy.")
                continue
            }
            data.payments[i].status = .refunded
            data.payments[i].refundedAmount = amount
            notify(data.payments[i].userID, .payment, "Refund issued", "\(Money.naira(amount)) refunded for receipt \(data.payments[i].reference).")
        }
    }

    private func makeReference() -> String {
        var ref: String
        repeat {
            ref = "RC-\(Int.random(in: 2100...9999))"
        } while data.payments.contains { $0.reference == ref }
        return ref
    }

    // MARK: - Messaging

    var myThreads: [ChatThread] {
        data.threads.filter { $0.userID == currentUserID || $0.agentID == currentUserID }.sorted { $0.lastActivity > $1.lastActivity }
    }

    func counterpart(in thread: ChatThread) -> Account? {
        account(thread.userID == currentUserID ? thread.agentID : thread.userID)
    }

    func isUnread(_ thread: ChatThread) -> Bool {
        guard let last = thread.messages.last, last.senderID != currentUserID else { return false }
        let lastRead = thread.userID == currentUserID ? thread.lastReadByUser : thread.lastReadByAgent
        return last.sentAt > lastRead
    }

    var unreadMessageCount: Int { myThreads.filter { isUnread($0) }.count }

    func openThread(for listing: Listing) throws -> UUID {
        guard let user = currentUser else { throw StoreError.notSignedIn }
        guard listing.agentID != user.id else { throw StoreError.ownListing }
        if let existing = data.threads.first(where: { $0.listingID == listing.id && $0.userID == user.id }) {
            return existing.id
        }
        let thread = ChatThread(id: UUID(), listingID: listing.id, userID: user.id, agentID: listing.agentID, messages: [], lastReadByUser: Date(), lastReadByAgent: Date())
        data.threads.append(thread)
        save()
        return thread.id
    }

    func send(_ text: String, in threadID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let user = currentUser, let idx = data.threads.firstIndex(where: { $0.id == threadID }) else { return }
        data.threads[idx].messages.append(ChatMessage(id: UUID(), senderID: user.id, text: trimmed, sentAt: Date()))
        let thread = data.threads[idx]
        let recipient = thread.userID == user.id ? thread.agentID : thread.userID
        let isFirstFromSender = thread.messages.filter { $0.senderID == user.id }.count == 1
        if isFirstFromSender || !data.notifications.contains(where: { $0.userID == recipient && $0.kind == .message && !$0.isRead }) {
            notify(recipient, .message, "New message from \(user.shortName)", trimmed)
        }
        markThreadRead(threadID)
        save()
    }

    func markThreadRead(_ threadID: UUID) {
        guard let idx = data.threads.firstIndex(where: { $0.id == threadID }) else { return }
        if data.threads[idx].userID == currentUserID {
            data.threads[idx].lastReadByUser = Date()
        } else {
            data.threads[idx].lastReadByAgent = Date()
        }
        save()
    }

    // MARK: - Notifications

    var myNotifications: [AppNotification] {
        data.notifications.filter { $0.userID == currentUserID }.sorted { $0.createdAt > $1.createdAt }
    }

    var unreadNotificationCount: Int { myNotifications.filter { !$0.isRead }.count }

    func markNotificationRead(_ id: UUID) {
        guard let idx = data.notifications.firstIndex(where: { $0.id == id }) else { return }
        data.notifications[idx].isRead = true
        save()
    }

    func markAllNotificationsRead() {
        for i in data.notifications.indices where data.notifications[i].userID == currentUserID {
            data.notifications[i].isRead = true
        }
        save()
    }

    private func notify(_ userID: UUID, _ kind: NotificationKind, _ title: String, _ body: String) {
        data.notifications.append(AppNotification(id: UUID(), userID: userID, kind: kind, title: title, body: body, createdAt: Date(), isRead: false))
    }

    private func notifyAdmins(_ kind: NotificationKind, _ title: String, _ body: String) {
        for admin in data.accounts where admin.role == .admin {
            notify(admin.id, kind, title, body)
        }
    }

    // MARK: - Agent listings

    var myListings: [Listing] {
        data.listings.filter { $0.agentID == currentUserID }.sorted { $0.createdAt > $1.createdAt }
    }

    func submitListing(_ draft: Listing) {
        guard let user = currentUser else { return }
        var listing = draft
        listing.id = UUID()
        listing.agentID = user.id
        listing.status = .pending
        listing.createdAt = Date()
        listing.weeklyViews = Array(repeating: 0, count: 7)
        listing.priceUnit = normalizedUnit(for: listing)
        applyHotelDerivedFields(&listing)
        data.listings.append(listing)
        notifyAdmins(.listing, "New listing to review", "\(listing.title) by \(user.name).")
        notify(user.id, .listing, "Listing submitted", "\(listing.title) is under review. We'll notify you once it's approved.")
        save()
    }

    func updateListing(_ updated: Listing) {
        guard let idx = data.listings.firstIndex(where: { $0.id == updated.id }) else { return }
        var listing = updated
        listing.priceUnit = normalizedUnit(for: listing)
        applyHotelDerivedFields(&listing)
        listing.status = .pending
        listing.rejectionReason = nil
        data.listings[idx] = listing
        notifyAdmins(.listing, "Listing updated", "\(listing.title) was edited and needs re-approval.")
        save()
    }

    private func applyHotelDerivedFields(_ listing: inout Listing) {
        guard listing.isHotel else { listing.hotel = nil; return }
        let hotel = listing.hotel ?? .blank()
        listing.hotel = hotel
        listing.price = hotel.lowestRate
        listing.sleeps = hotel.maxCapacity
        listing.bedrooms = hotel.totalRooms
        listing.bathrooms = 0
    }

    private func normalizedUnit(for listing: Listing) -> PriceUnit {
        switch listing.category {
        case .shortlet, .hotel: .night
        case .sale: .total
        case .rent: listing.priceUnit == .month ? .month : .year
        }
    }

    func setAvailability(_ id: UUID, available: Bool) {
        guard let idx = data.listings.firstIndex(where: { $0.id == id }) else { return }
        let status = data.listings[idx].status
        guard status == .live || status == .unavailable else { return }
        data.listings[idx].status = available ? .live : .unavailable
        save()
    }

    func deleteListing(_ id: UUID) {
        data.listings.removeAll { $0.id == id }
        for i in data.accounts.indices { data.accounts[i].favoriteIDs.removeAll { $0 == id } }
        save()
    }

    func recordView(_ id: UUID) {
        guard let idx = data.listings.firstIndex(where: { $0.id == id }), data.listings[idx].agentID != currentUserID else { return }
        if data.listings[idx].weeklyViews.count < 7 { data.listings[idx].weeklyViews = Array(repeating: 0, count: 7) }
        data.listings[idx].weeklyViews[6] += 1
        save()
    }

    func report(listingID: UUID, reason: String, details: String) throws {
        guard let user = currentUser else { throw StoreError.notSignedIn }
        data.reports.append(ListingReport(id: UUID(), listingID: listingID, reporterID: user.id, reason: reason, details: details, createdAt: Date(), isResolved: false))
        notifyAdmins(.system, "Listing reported", "\(listing(listingID)?.title ?? "A listing") was reported: \(reason).")
        save()
    }

    // MARK: - Admin

    var adminStats: AdminStats {
        let agents = data.accounts.filter { $0.role == .agent }
        let owners = data.accounts.filter { $0.role == .hotelOwner }
        let live = data.bookings.filter { $0.status != .cancelled && $0.status != .declined }
        return AdminStats(
            users: data.accounts.filter { $0.role != .admin }.count,
            agents: agents.count,
            approvedAgents: agents.filter(\.isVerified).count,
            hotelOwners: owners.count,
            pendingHotelOwners: owners.filter { !$0.isVerified && !$0.isSuspended }.count,
            hotelReservations: live.filter { $0.kind == .hotelReservation }.count,
            shortletBookings: live.filter { $0.kind == .shortletBooking }.count,
            rentalInquiries: data.bookings.filter { $0.category == .rent }.count,
            saleInquiries: data.bookings.filter { $0.category == .sale }.count,
            activeListings: liveListings.count,
            pendingListings: data.listings.filter { $0.status == .pending }.count,
            bookingRequests: data.bookings.filter { $0.status == .pending }.count,
            openReports: data.reports.filter { !$0.isResolved }.count,
            revenue: data.payments.filter { $0.status == .paid }.reduce(0) { $0 + $1.serviceFee }
        )
    }

    func approveListing(_ id: UUID) {
        guard let idx = data.listings.firstIndex(where: { $0.id == id }) else { return }
        data.listings[idx].status = .live
        data.listings[idx].rejectionReason = nil
        notify(data.listings[idx].agentID, .listing, "Listing approved", "\(data.listings[idx].title) is now live on Homestead.")
        save()
    }

    func rejectListing(_ id: UUID, reason: String) {
        guard let idx = data.listings.firstIndex(where: { $0.id == id }) else { return }
        data.listings[idx].status = .rejected
        data.listings[idx].rejectionReason = reason.isEmpty ? "Does not meet listing guidelines." : reason
        notify(data.listings[idx].agentID, .listing, "Listing not approved", "\(data.listings[idx].title): \(data.listings[idx].rejectionReason ?? "")")
        save()
    }

    func setFeatured(_ id: UUID, featured: Bool) {
        guard let idx = data.listings.firstIndex(where: { $0.id == id }) else { return }
        data.listings[idx].isFeatured = featured
        save()
    }

    func setAgentVerified(_ id: UUID, verified: Bool) {
        guard let idx = data.accounts.firstIndex(where: { $0.id == id }) else { return }
        data.accounts[idx].isVerified = verified
        if data.accounts[idx].role == .hotelOwner {
            notify(id, .system, verified ? "Application approved" : "Approval removed", verified ? "Your hotel-owner account is approved. Hotels you submit show the Verified hotel badge." : "Contact support to restore your hotel account.")
        } else {
            notify(id, .system, verified ? "You're verified" : "Verification removed", verified ? "Your listings now show the Verified agent badge." : "Contact support to restore verification.")
        }
        save()
    }

    func setSuspended(_ id: UUID, suspended: Bool) {
        guard let idx = data.accounts.firstIndex(where: { $0.id == id }), data.accounts[idx].role != .admin else { return }
        data.accounts[idx].isSuspended = suspended
        if suspended {
            for i in data.listings.indices where data.listings[i].agentID == id && data.listings[i].status == .live {
                data.listings[i].status = .unavailable
            }
        }
        save()
    }

    func resolveReport(_ id: UUID, takeDown: Bool) {
        guard let idx = data.reports.firstIndex(where: { $0.id == id }) else { return }
        data.reports[idx].isResolved = true
        if takeDown { rejectListing(data.reports[idx].listingID, reason: "Removed after a user report: \(data.reports[idx].reason).") }
        save()
    }

    func refundPayment(_ id: UUID) {
        guard let idx = data.payments.firstIndex(where: { $0.id == id }), data.payments[idx].status == .paid else { return }
        data.payments[idx].status = .refunded
        notify(data.payments[idx].userID, .payment, "Refund issued", "\(Money.naira(data.payments[idx].total)) refunded for receipt \(data.payments[idx].reference).")
        save()
    }

    func adminCancelBooking(_ id: UUID) {
        guard let idx = data.bookings.firstIndex(where: { $0.id == id }) else { return }
        data.bookings[idx].status = .cancelled
        refundPayments(for: id)
        notify(data.bookings[idx].userID, .booking, "Booking cancelled", "An administrator cancelled your request for \(listing(data.bookings[idx].listingID)?.title ?? "a listing").")
        save()
    }

    /// Restores the starter data set (used from the admin dashboard).
    func resetDemoData() {
        data = SeedData.make()
        save()
        signOut()
    }
}
