import SwiftUI

/// Rooms list on a hotel detail page with live availability for the chosen stay.
struct HotelRoomsSection: View {
    let listing: Listing
    let onReserve: (RoomType) -> Void

    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        let rooms = listing.hotel?.rooms ?? []
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your room").font(.title3.bold()).foregroundStyle(Theme.ink)
            StaySearchCard(stay: $router.hotelStay)
            ForEach(rooms) { room in
                RoomTypeCard(listing: listing, room: room, stay: router.hotelStay, isOwner: store.isOwner(listing)) {
                    onReserve(room)
                }
            }
            if rooms.isEmpty {
                Text("Rooms haven't been added yet.").font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
    }
}

struct RoomTypeCard: View {
    let listing: Listing
    let room: RoomType
    let stay: SearchFilters
    var isOwner: Bool = false
    let onReserve: () -> Void

    @Environment(AppStore.self) private var store

    var body: some View {
        let left = stay.hasDates
            ? store.roomsAvailable(listing: listing, roomTypeID: room.id, from: stay.checkIn ?? Date(), to: stay.checkOut ?? Date())
            : room.totalRooms
        let fitsGuests = room.capacity * stay.rooms >= stay.guests
        let canBook = room.isOpen && left >= stay.rooms && fitsGuests && listing.status == .live && !isOwner
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 130)
                .overlay { ListingPhoto(name: room.imageName ?? listing.imageNames.first) }
                .clipped()
                .overlay(alignment: .topLeading) {
                    Label(room.kind.title, systemImage: room.kind.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.94), in: .capsule)
                        .padding(10)
                }
            VStack(alignment: .leading, spacing: 8) {
                Text(room.name).font(.headline).foregroundStyle(Theme.ink)
                HStack(spacing: 12) {
                    Label(room.bedInfo, systemImage: "bed.double")
                    Label("\(room.capacity)", systemImage: "person.2")
                    Label("\(room.sizeSqm) m²", systemImage: "square.dashed")
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
                if !room.amenities.isEmpty {
                    Text(room.amenities.map(\.title).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
                Divider()
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(Money.naira(room.pricePerNight)).font(.title3.bold()).monospacedDigit().foregroundStyle(Theme.ink)
                            Text("/ night").font(.caption).foregroundStyle(Theme.muted)
                        }
                        availabilityText(left: left, fitsGuests: fitsGuests)
                    }
                    Spacer()
                    if !isOwner {
                        Button("Reserve", action: onReserve)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(canBook ? Theme.primary : Theme.muted.opacity(0.4), in: .capsule)
                            .disabled(!canBook)
                    }
                }
            }
            .padding(14)
        }
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .shadow(color: Theme.ink.opacity(0.05), radius: 12, y: 4)
    }

    @ViewBuilder
    private func availabilityText(left: Int, fitsGuests: Bool) -> some View {
        if !room.isOpen {
            Text("Not taking reservations").font(.caption.weight(.semibold)).foregroundStyle(Theme.danger)
        } else if left == 0 {
            Text("Sold out for these dates").font(.caption.weight(.semibold)).foregroundStyle(Theme.danger)
        } else if !fitsGuests {
            Text("Fits \(room.capacity) per room — add a room").font(.caption.weight(.semibold)).foregroundStyle(BadgeTone.warning.foreground)
        } else if left <= 3 {
            Text("Only \(left) left").font(.caption.weight(.semibold)).foregroundStyle(BadgeTone.warning.foreground)
        } else {
            Text("\(left) rooms available").font(.caption.weight(.semibold)).foregroundStyle(BadgeTone.success.foreground)
        }
    }
}

struct HotelPoliciesCard: View {
    let hotel: HotelDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Policies").font(.title3.bold()).foregroundStyle(Theme.ink)
            HStack(spacing: 0) {
                timeCell("Check-in", hotel.checkInTime, "arrow.down.to.line")
                Divider().frame(height: 36)
                timeCell("Check-out", hotel.checkOutTime, "arrow.up.to.line")
            }
            Divider()
            policyRow("calendar.badge.minus", "\(hotel.policy.title) cancellation", hotel.policy.summary)
            policyRow("person.text.rectangle", "Check-in requirements", hotel.checkInRequirements)
        }
        .card()
    }

    private func timeCell(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Theme.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(Theme.muted)
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func policyRow(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.primary).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(text).font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
    }
}

/// Guest reviews with rating summary and a write-review entry point for eligible guests.
struct ReviewsSection: View {
    let listing: Listing
    @Environment(AppStore.self) private var store
    @State private var showWrite = false
    @State private var showAll = false

    var body: some View {
        let reviews = store.reviews(for: listing.id)
        let canReview = store.canReview(listing.id)
        if !reviews.isEmpty || canReview || listing.reviewCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Guest reviews").font(.title3.bold()).foregroundStyle(Theme.ink)
                    Spacer()
                    if listing.reviewCount > 0 {
                        Image(systemName: "star.fill").foregroundStyle(Theme.accent)
                        Text(listing.rating, format: .number.precision(.fractionLength(1))).font(.headline).foregroundStyle(Theme.ink)
                        Text("· \(listing.reviewCount)").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                ForEach(showAll ? reviews : Array(reviews.prefix(2))) { review in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle().fill(Theme.primarySoft).frame(width: 32, height: 32)
                                .overlay(Text(String(review.authorName.prefix(1))).font(.subheadline.bold()).foregroundStyle(Theme.primary))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(review.authorName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                Text(review.createdAt.formatted(.dateTime.month(.wide).year())).font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            StarRow(count: review.rating)
                        }
                        if !review.text.isEmpty {
                            Text(review.text).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))
                        }
                    }
                    .card(padding: 14)
                }
                if reviews.count > 2 {
                    Button(showAll ? "Show fewer" : "Show all \(reviews.count) written reviews") {
                        withAnimation(.snappy) { showAll.toggle() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                }
                if canReview {
                    Button {
                        showWrite = true
                    } label: {
                        Label("Write a review", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .sheet(isPresented: $showWrite) { WriteReviewSheet(listing: listing) }
        }
    }
}

struct WriteReviewSheet: View {
    let listing: Listing
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 5
    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Spacer()
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { rating = value }
                            } label: {
                                Image(systemName: value <= rating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundStyle(Theme.accent)
                                    .symbolEffect(.bounce, value: rating == value)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(value) star")
                        }
                        Spacer()
                    }
                    .sensoryFeedback(.selection, trigger: rating)
                } header: {
                    Text("How was your stay at \(listing.title)?")
                }
                Section("Your review") {
                    TextField("What did you love? What could be better?", text: $text, axis: .vertical).lineLimit(4...8)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.danger)
                }
            }
            .tint(Theme.primary)
            .navigationTitle("Write a review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        do {
                            try store.addReview(listingID: listing.id, rating: rating, text: text)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Reserve a hotel room: confirm dates, rooms and guests, see the price and policy, then pay.
struct HotelReservationSheet: View {
    let listing: Listing
    let roomID: UUID

    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var stay = SearchFilters.defaultStay()
    @State private var message = ""
    @State private var showCheckout = false
    @State private var confirmed: Booking?
    @State private var errorMessage: String?

    private var room: RoomType? { store.listing(listing.id)?.room(roomID) }

    private var available: Int {
        guard stay.hasDates else { return 0 }
        return store.roomsAvailable(listing: listing, roomTypeID: roomID, from: stay.checkIn ?? Date(), to: stay.checkOut ?? Date())
    }

    private var maxGuests: Int { (room?.capacity ?? 1) * stay.rooms }

    private var canContinue: Bool {
        stay.hasDates && available >= stay.rooms && stay.guests <= maxGuests && (room?.isOpen ?? false)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let confirmed {
                    BookingSuccessView(
                        title: "Reservation confirmed",
                        message: "Your room is booked and paid. Show confirmation \(confirmed.confirmationCode) with a valid ID at check-in.",
                        detail: confirmed.dateSummary
                    ) { dismiss() }
                } else if let room {
                    form(room)
                } else {
                    ContentUnavailableView("Room unavailable", systemImage: "bed.double")
                }
            }
            .navigationTitle(confirmed == nil ? "Reserve room" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if confirmed == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
            }
            .navigationDestination(isPresented: $showCheckout) {
                if let room {
                    CheckoutView(title: "\(listing.title) · \(room.name)", amount: room.quote(nights: stay.nights, rooms: stay.rooms).total) { method, last4 in
                        do {
                            let booking = try store.reserveHotel(
                                listing: listing, roomTypeID: roomID, checkIn: stay.checkIn ?? Date(), checkOut: stay.checkOut ?? Date(),
                                guests: stay.guests, rooms: stay.rooms, message: message, method: method, cardLast4: last4
                            )
                            showCheckout = false
                            withAnimation(.spring) { confirmed = booking }
                            return true
                        } catch {
                            errorMessage = error.localizedDescription
                            return false
                        }
                    }
                }
            }
            .alert("Couldn't complete reservation", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { showCheckout = false }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(showCheckout)
        .onAppear {
            stay = router.hotelStay
            if !stay.hasDates { stay = SearchFilters.defaultStay() }
        }
        .onChange(of: stay.rooms) { _, _ in
            if stay.guests > maxGuests { stay.guests = maxGuests }
        }
    }

    private func form(_ room: RoomType) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ListingPhoto(name: room.imageName ?? listing.imageNames.first)
                        .frame(width: 76, height: 76)
                        .clipShape(.rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(room.name).font(.headline).foregroundStyle(Theme.ink)
                        Text(listing.title).font(.subheadline).foregroundStyle(Theme.muted)
                        Text("\(room.bedInfo) · up to \(room.capacity) guests").font(.caption).foregroundStyle(Theme.muted)
                    }
                }

                StaySearchCard(stay: $stay)

                availabilityBanner

                VStack(alignment: .leading, spacing: 6) {
                    Text("Special requests").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                    TextField("Arrival time, high floor, airport pickup…", text: $message, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(Theme.surface, in: .rect(cornerRadius: 14))
                }

                priceBreakdown(room)

                if let policy = listing.hotel?.policy {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(policy.title) cancellation").font(.subheadline.weight(.semibold))
                            Text(policy.summary).font(.footnote)
                        }
                    } icon: {
                        Image(systemName: "calendar.badge.minus")
                    }
                    .foregroundStyle(Theme.ink)
                    .card(padding: 14)
                }

                Button("Continue to payment") { showCheckout = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canContinue)

                Label("Availability is re-checked the moment you pay, so rooms are never double-booked.", systemImage: "lock.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
        }
        .screenBackground()
    }

    @ViewBuilder
    private var availabilityBanner: some View {
        let ok = canContinue
        let text: String = {
            if !stay.hasDates { return "Choose at least one night" }
            if available < stay.rooms { return available == 0 ? "Sold out for these dates" : "Only \(available) room\(available == 1 ? "" : "s") left for these dates" }
            if stay.guests > maxGuests { return "\(stay.rooms) room\(stay.rooms == 1 ? "" : "s") fit up to \(maxGuests) guests" }
            return "\(available) room\(available == 1 ? "" : "s") available · \(stay.nights) night\(stay.nights == 1 ? "" : "s")"
        }()
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(text).font(.subheadline.weight(.medium))
            Spacer()
        }
        .foregroundStyle(ok ? BadgeTone.success.foreground : BadgeTone.danger.foreground)
        .padding(12)
        .background(ok ? BadgeTone.success.background : BadgeTone.danger.background, in: .rect(cornerRadius: 12))
        .animation(.snappy, value: ok)
    }

    private func priceBreakdown(_ room: RoomType) -> some View {
        let nights = max(stay.nights, 1)
        let quote = room.quote(nights: nights, rooms: stay.rooms)
        return VStack(spacing: 10) {
            InfoRow(title: "\(Money.naira(room.pricePerNight)) × \(nights) night\(nights == 1 ? "" : "s") × \(stay.rooms) room\(stay.rooms == 1 ? "" : "s")", value: Money.naira(quote.subtotal))
            InfoRow(title: "Service fee (5%)", value: Money.naira(quote.fee))
            Divider()
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text(Money.naira(quote.total)).font(.headline).monospacedDigit().contentTransition(.numericText())
            }
            .foregroundStyle(Theme.ink)
        }
        .card()
    }
}
