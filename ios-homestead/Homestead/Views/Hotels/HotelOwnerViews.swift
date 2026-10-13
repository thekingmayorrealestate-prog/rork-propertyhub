import SwiftUI
import Charts

/// Dashboard for hotel owners and managers: occupancy, arrivals, revenue, hotels and reservations.
struct HotelOwnerDashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showAccount = false
    @State private var showEditor = false
    @State private var chartAppeared = false

    private var hotels: [Listing] { store.myListings.filter(\.isHotel) }
    private var reservations: [Booking] { store.incomingRequests.filter { $0.kind == .hotelReservation } }

    private var occupancy: [DayPoint] {
        let cal = Calendar.current
        let live = hotels.filter { $0.status == .live }
        return (0..<7).map { i in
            let date = cal.date(byAdding: .day, value: i, to: Date()) ?? Date()
            let booked = live.reduce(0) { $0 + store.roomsBooked(listing: $1, on: date) }
            return DayPoint(id: i, label: date.formatted(.dateTime.weekday(.abbreviated)), value: booked)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if store.currentUser?.isVerified == false { approvalBanner }
                statsCard
                hotelsSection
                arrivalsSection
            }
            .padding(.vertical, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAccount) { AccountSheet() }
        .sheet(isPresented: $showEditor) { ListingEditorView(existing: nil) }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hotel Dashboard").font(.subheadline.weight(.medium)).foregroundStyle(Theme.muted)
                Text(store.currentUser?.agencyName ?? "Your hotels").font(.largeTitle.bold()).foregroundStyle(Theme.ink).lineLimit(2)
                Text("Rooms, rates and reservations at a glance.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button {
                showAccount = true
            } label: {
                VStack(spacing: 4) {
                    AvatarView(account: store.currentUser, size: 54)
                        .overlay(alignment: .topTrailing) {
                            if store.unreadNotificationCount + store.unreadMessageCount > 0 {
                                Circle().fill(Theme.accent).frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Theme.canvas, lineWidth: 2))
                            }
                        }
                    Text(store.currentUser?.shortName ?? "").font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text("Manager").font(.caption2).foregroundStyle(Theme.muted)
                }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Account")
        }
        .padding(.horizontal, 16)
    }

    private var approvalBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
            Text("Your hotel-owner application is under review. You can set up hotels and rooms now; they go live once approved.")
                .font(.footnote)
        }
        .foregroundStyle(BadgeTone.warning.foreground)
        .padding(14)
        .background(BadgeTone.warning.background, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private var statsCard: some View {
        let live = hotels.filter { $0.status == .live }
        let totalRooms = live.reduce(0) { $0 + ($1.hotel?.openRooms.reduce(0) { $0 + $1.totalRooms } ?? 0) }
        let tonight = occupancy.first?.value ?? 0
        let rate = totalRooms > 0 ? Int((Double(tonight) / Double(totalRooms) * 100).rounded()) : 0
        let hotelIDs = Set(hotels.map(\.id))
        let revenue = store.data.payments.filter { hotelIDs.contains($0.listingID) && $0.status == .paid }.reduce(0) { $0 + $1.amount }
        let upcoming = reservations.filter { $0.isUpcoming }.count
        return VStack(spacing: 18) {
            HStack(spacing: 0) {
                metric("\(rate)%", "occupancy tonight")
                Divider().frame(height: 44)
                metric("\(upcoming)", "upcoming stays")
                Divider().frame(height: 44)
                metric(Money.compact(revenue), "room revenue")
            }
            HStack {
                Text("Rooms booked · next 7 nights").font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(totalRooms) rooms open").font(.caption).foregroundStyle(Theme.muted)
            }
            Chart(occupancy) { point in
                BarMark(x: .value("Night", point.label), y: .value("Rooms", chartAppeared ? point.value : 0), width: .ratio(0.62))
                    .foregroundStyle(point.id == 0 ? Theme.accent : Theme.primary.opacity(0.82))
                    .cornerRadius(5)
            }
            .chartYScale(domain: 0...max(totalRooms, 4))
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel().foregroundStyle(Theme.muted)
                }
            }
            .frame(height: 150)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) { chartAppeared = true }
            }
        }
        .card()
        .padding(.horizontal, 16)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).monospacedDigit().foregroundStyle(Theme.ink).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var hotelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My Hotels")
            VStack(spacing: 0) {
                ForEach(hotels) { hotel in
                    NavigationLink(value: Route.agentListing(hotel.id)) {
                        HStack(spacing: 14) {
                            ListingPhoto(name: hotel.imageNames.first)
                                .frame(width: 70, height: 70)
                                .clipShape(.rect(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(hotel.title).font(.headline).foregroundStyle(Theme.ink).lineLimit(1)
                                Text("\(hotel.hotel?.totalRooms ?? 0) rooms · \(hotel.locationLine)").font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1)
                                Text("Booked tonight: \(store.roomsBooked(listing: hotel, on: Date()))").font(.caption).foregroundStyle(Theme.accent)
                            }
                            Spacer(minLength: 4)
                            StatusBadge(text: hotel.status.title, tone: hotel.status.tone, showsDot: true)
                        }
                        .padding(10)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 96)
                }
                Button {
                    showEditor = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 70, height: 70)
                            .background(Theme.primarySoft, in: .rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Add a hotel").font(.headline).foregroundStyle(Theme.ink)
                            Text("Photos, rooms, rates and policies").font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                    }
                    .padding(10)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .card(padding: 4)
            .padding(.horizontal, 16)
        }
    }

    private var arrivalsSection: some View {
        let upcoming = reservations.filter(\.isUpcoming).sorted { ($0.checkIn ?? .distantFuture) < ($1.checkIn ?? .distantFuture) }
        let shown = Array(upcoming.prefix(4))
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Upcoming Arrivals", actionTitle: "All reservations") { router.push(.agentRequests) }
            VStack(spacing: 0) {
                if shown.isEmpty {
                    Text("No upcoming reservations yet.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(shown) { booking in
                    NavigationLink(value: Route.booking(booking.id)) {
                        arrivalRow(booking)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 76)
                }
                NavigationLink(value: Route.messages) {
                    HStack(spacing: 14) {
                        Image(systemName: "bubble.left")
                            .foregroundStyle(Theme.accent)
                            .frame(width: 46, height: 46)
                            .background(Theme.accentSoft, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            let unread = store.unreadMessageCount
                            Text(unread > 0 ? "\(unread) new message\(unread == 1 ? "" : "s")" : "Guest messages")
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            Text("Questions from guests and enquirers").font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                    }
                    .padding(12)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .card(padding: 4)
            .padding(.horizontal, 16)
        }
    }

    private func arrivalRow(_ booking: Booking) -> some View {
        let listing = store.listing(booking.listingID)
        let room = listing?.room(booking.roomTypeID)
        return HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(booking.checkIn?.formatted(.dateTime.month(.abbreviated)) ?? "")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .textCase(.uppercase)
                Text(booking.checkIn?.formatted(.dateTime.day()) ?? "")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 50, height: 50)
            .background(Theme.accentSoft, in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(store.account(booking.userID)?.name ?? "Guest").font(.headline).foregroundStyle(Theme.ink).lineLimit(1)
                Text("\(booking.rooms) × \(room?.name ?? "Room") · \(booking.nights) night\(booking.nights == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Text(listing?.title ?? "").font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            StatusBadge(text: booking.status.title, tone: booking.status.tone)
        }
        .padding(12)
        .contentShape(.rect)
    }
}

/// Room inventory: rates, number of rooms, open/closed and occupancy per room type.
struct HotelRoomsView: View {
    let listingID: UUID

    @Environment(AppStore.self) private var store
    @State private var editing: RoomType?
    @State private var isAdding = false

    var body: some View {
        Group {
            if let listing = store.listing(listingID), let hotel = listing.hotel {
                List {
                    Section {
                        ForEach(hotel.rooms) { room in
                            roomRow(room, listing: listing)
                                .contentShape(.rect)
                                .onTapGesture { editing = room }
                                .swipeActions {
                                    Button("Delete", role: .destructive) { store.deleteRoom(room.id, from: listingID) }
                                    Button("Edit") { editing = room }.tint(Theme.primary)
                                }
                        }
                    } footer: {
                        Text("Rate and inventory changes apply immediately. Existing reservations keep the price they were booked at.")
                    }
                    Section {
                        Button {
                            isAdding = true
                        } label: {
                            Label("Add room type", systemImage: "plus.circle.fill")
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            } else {
                ContentUnavailableView("Hotel not found", systemImage: "bed.double")
            }
        }
        .screenBackground()
        .navigationTitle("Rooms & rates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $editing) { room in
            RoomEditorSheet(existing: room) { updated in store.updateRoom(updated, in: listingID) }
        }
        .sheet(isPresented: $isAdding) {
            RoomEditorSheet(existing: nil) { room in store.addRoom(room, to: listingID) }
        }
    }

    private func roomRow(_ room: RoomType, listing: Listing) -> some View {
        let tonight = store.roomsAvailable(listing: listing, roomTypeID: room.id, from: Date(), to: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ListingPhoto(name: room.imageName ?? listing.imageNames.first)
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name).font(.headline)
                    Text("\(room.kind.title) · sleeps \(room.capacity) · \(room.totalRooms) rooms").font(.caption).foregroundStyle(Theme.muted)
                    Text("\(Money.naira(room.pricePerNight)) / night").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                Spacer()
            }
            HStack {
                Text(room.isOpen ? "\(tonight) of \(room.totalRooms) free tonight" : "Closed to new reservations")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(room.isOpen ? Theme.muted : Theme.danger)
                Spacer()
                Toggle("Open", isOn: Binding(get: { room.isOpen }, set: { store.setRoomOpen(room.id, in: listingID, open: $0) }))
                    .labelsHidden()
                    .tint(Theme.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Create or edit a room type: name, kind, nightly rate, capacity, inventory and amenities.
struct RoomEditorSheet: View {
    let existing: RoomType?
    let onSave: (RoomType) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = RoomType.blank()
    @State private var priceText = ""
    @State private var sizeText = ""

    private let roomImages = ["hotel_king_room", "hotel_suite_living_area", "guesthouse_twin_room", "serviced_suite_bedroom", "luxury_bedroom_city_view"]

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && (Int(priceText.filter(\.isNumber)) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Room") {
                    TextField("Name, e.g. Deluxe King", text: $draft.name)
                    Picker("Room type", selection: $draft.kind) {
                        ForEach(RoomKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    .onChange(of: draft.kind) { _, kind in
                        if existing == nil { draft.capacity = kind.defaultCapacity }
                    }
                    TextField("Beds, e.g. 1 king bed", text: $draft.bedInfo)
                }
                Section("Rate & inventory") {
                    HStack {
                        Text("₦")
                        TextField("Price per night", text: $priceText).keyboardType(.numberPad)
                    }
                    Stepper("Sleeps \(draft.capacity)", value: $draft.capacity, in: 1...10)
                    Stepper("\(draft.totalRooms) room\(draft.totalRooms == 1 ? "" : "s") of this type", value: $draft.totalRooms, in: 1...200)
                    HStack {
                        Text("Size")
                        Spacer()
                        TextField("m²", text: $sizeText).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(maxWidth: 80)
                        Text("m²").foregroundStyle(Theme.muted)
                    }
                    Toggle("Open for reservations", isOn: $draft.isOpen)
                }
                Section("Photo") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(roomImages, id: \.self) { name in
                                Button {
                                    draft.imageName = name
                                } label: {
                                    ListingPhoto(name: name)
                                        .frame(width: 90, height: 66)
                                        .clipShape(.rect(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accent, lineWidth: draft.imageName == name ? 3 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                }
                Section("Room amenities") {
                    ForEach([Facility.wifi, .ac, .breakfast, .roomService, .kitchen, .spa]) { facility in
                        Toggle(isOn: Binding(
                            get: { draft.amenities.contains(facility) },
                            set: { on in if on { draft.amenities.append(facility) } else { draft.amenities.removeAll { $0 == facility } } }
                        )) {
                            Label(facility.title, systemImage: facility.symbol)
                        }
                    }
                }
            }
            .tint(Theme.primary)
            .navigationTitle(existing == nil ? "New room type" : "Edit room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.pricePerNight = Int(priceText.filter(\.isNumber)) ?? 0
                        draft.sizeSqm = Int(sizeText.filter(\.isNumber)) ?? 0
                        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            if let existing {
                draft = existing
                priceText = String(existing.pricePerNight)
                sizeText = String(existing.sizeSqm)
            } else {
                draft = .blank()
                draft.imageName = roomImages.first
                sizeText = String(draft.sizeSqm)
            }
        }
    }
}

struct BecomeHotelOwnerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var hotelName = ""
    @State private var phone = ""
    @State private var accepted = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("List hotels, guesthouses and resorts. Our team reviews every hotel-owner application and hotel before it's published.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                Section("Business details") {
                    TextField("Hotel or company name", text: $hotelName)
                    TextField("Business phone", text: $phone).keyboardType(.phonePad)
                }
                Section {
                    Toggle("I own or am authorised to manage the properties I list", isOn: $accepted)
                        .tint(Theme.primary)
                }
            }
            .navigationTitle("List your hotel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        store.becomeHotelOwner(hotelName: hotelName, phone: phone)
                        dismiss()
                    }
                    .disabled(hotelName.trimmingCharacters(in: .whitespaces).isEmpty || phone.count < 7 || !accepted)
                }
            }
        }
        .onAppear { phone = store.currentUser?.phone ?? "" }
    }
}
