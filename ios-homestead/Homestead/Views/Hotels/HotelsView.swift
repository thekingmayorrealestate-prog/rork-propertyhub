import SwiftUI

/// Hotel discovery: destination, dates, guests & rooms, room type, budget and facilities with live availability.
struct HotelsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showCompare = false
    @State private var budget: Budget = .any

    enum Budget: String, CaseIterable, Identifiable {
        case any, under100, mid, premium
        var id: String { rawValue }
        var title: String {
            switch self {
            case .any: "Any budget"
            case .under100: "Under ₦100k"
            case .mid: "₦100k – ₦200k"
            case .premium: "₦200k+"
            }
        }
        var range: (Int?, Int?) {
            switch self {
            case .any: (nil, nil)
            case .under100: (nil, 99_999)
            case .mid: (100_000, 200_000)
            case .premium: (200_001, nil)
            }
        }
    }

    private var filters: SearchFilters {
        var f = router.hotelStay
        f.category = .hotel
        f.minPrice = budget.range.0
        f.maxPrice = budget.range.1
        return f
    }

    private var results: [Listing] { store.search(filters) }

    var body: some View {
        @Bindable var router = router
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StaySearchCard(stay: $router.hotelStay, showsDestination: true)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        Menu {
                            Picker("Budget", selection: $budget) {
                                ForEach(Budget.allCases) { Text($0.title).tag($0) }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "banknote")
                                Text(budget.title)
                                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(budget == .any ? Theme.ink : .white)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(budget == .any ? Theme.surface : Theme.primary, in: .capsule)
                        }
                        FilterChip(title: "Any room", selected: router.hotelStay.roomKind == nil) { router.hotelStay.roomKind = nil }
                        ForEach(RoomKind.allCases) { kind in
                            FilterChip(title: kind.title, selected: router.hotelStay.roomKind == kind, symbol: kind.symbol) {
                                router.hotelStay.roomKind = router.hotelStay.roomKind == kind ? nil : kind
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollIndicators(.hidden)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Facility.hotelFacilities) { facility in
                            let on = router.hotelStay.facilities.contains(facility)
                            FilterChip(title: facility.title, selected: on, symbol: facility.symbol) {
                                if on { router.hotelStay.facilities.remove(facility) } else { router.hotelStay.facilities.insert(facility) }
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollIndicators(.hidden)

                HStack {
                    Text("\(results.count) hotel\(results.count == 1 ? "" : "s") available")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .contentTransition(.numericText())
                    Spacer()
                    if router.hotelStay.hasDates {
                        Text("\(router.hotelStay.nights) night\(router.hotelStay.nights == 1 ? "" : "s")")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.primarySoft, in: .capsule)
                    }
                }
                .padding(.horizontal, 16)

                LazyVStack(spacing: 14) {
                    ForEach(results) { listing in
                        NavigationLink(value: Route.listing(listing.id)) {
                            HotelResultCard(listing: listing, stay: filters)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 16)

                if results.isEmpty {
                    ContentUnavailableView {
                        Label("No rooms match", systemImage: "bed.double")
                    } description: {
                        Text("Try other dates, fewer guests per room, or a different budget.")
                    } actions: {
                        Button("Reset filters") {
                            budget = .any
                            router.hotelStay = SearchFilters.defaultStay()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 200)
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, router.compareIDs.isEmpty ? 0 : 80)
            .animation(.snappy, value: results.map(\.id))
        }
        .scrollDismissesKeyboard(.immediately)
        .screenBackground()
        .navigationTitle("Hotels & Resorts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $router.hotelStay.sort) {
                        ForEach(SortOption.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort")
            }
        }
        .overlay(alignment: .bottom) {
            CompareTray { showCompare = true }
        }
        .sheet(isPresented: $showCompare) { HotelCompareView() }
    }
}

/// Destination, dates, guests and rooms selector shared by hotel search and hotel detail.
struct StaySearchCard: View {
    @Binding var stay: SearchFilters
    var showsDestination: Bool = false

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        VStack(spacing: 0) {
            if showsDestination {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.primary)
                    TextField("Destination, area or hotel", text: $stay.query)
                        .submitLabel(.search)
                    Menu {
                        Picker("City", selection: $stay.city) {
                            Text("All cities").tag(String?.none)
                            ForEach(SeedData.cities, id: \.self) { Text($0).tag(Optional($0)) }
                        }
                    } label: {
                        Text(stay.city ?? "All cities")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .frame(minHeight: 50)
                Divider()
            }
            HStack(spacing: 0) {
                dateField("Check in", date: Binding(get: { stay.checkIn ?? today }, set: { newValue in
                    stay.checkIn = newValue
                    if (stay.checkOut ?? newValue) <= newValue {
                        stay.checkOut = Calendar.current.date(byAdding: .day, value: 1, to: newValue)
                    }
                }), from: today)
                Divider().frame(height: 40)
                dateField("Check out", date: Binding(get: { stay.checkOut ?? today }, set: { stay.checkOut = $0 }),
                          from: Calendar.current.date(byAdding: .day, value: 1, to: stay.checkIn ?? today) ?? today)
                    .padding(.leading, 12)
            }
            .padding(.vertical, 8)
            Divider()
            HStack(spacing: 12) {
                counter("person.2", "Guests", value: $stay.guests, range: 1...20)
                Divider().frame(height: 30)
                counter("door.left.hand.closed", "Rooms", value: $stay.rooms, range: 1...10)
            }
            .padding(.vertical, 8)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cardRadius))
        .shadow(color: Theme.ink.opacity(0.05), radius: 14, y: 4)
    }

    private func dateField(_ title: String, date: Binding<Date>, from: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Theme.muted)
            DatePicker(title, selection: date, in: from..., displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func counter(_ symbol: String, _ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(Theme.muted).frame(width: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption).foregroundStyle(Theme.muted)
                Text("\(value.wrappedValue)").font(.headline).monospacedDigit().contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                stepButton("minus", enabled: value.wrappedValue > range.lowerBound) { value.wrappedValue -= 1 }
                stepButton("plus", enabled: value.wrappedValue < range.upperBound) { value.wrappedValue += 1 }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(enabled ? Theme.primary : Theme.muted.opacity(0.4))
                .frame(width: 32, height: 32)
                .background(enabled ? Theme.primarySoft : Theme.canvas, in: .circle)
                .frame(width: 40, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .sensoryFeedback(.selection, trigger: enabled)
    }
}

/// Large hotel result card with stars, rating, availability and stay total.
struct HotelResultCard: View {
    let listing: Listing
    let stay: SearchFilters

    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let rooms = store.matchingRooms(listing, filters: stay)
        let cheapest = rooms.min { $0.pricePerNight < $1.pricePerNight }
        let comparing = router.compareIDs.contains(listing.id)
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 170)
                .overlay { ListingPhoto(name: listing.imageNames.first) }
                .clipped()
                .overlay(alignment: .topTrailing) { FavoriteButton(listingID: listing.id).padding(4) }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 6) {
                        if store.isAgentVerified(listing) { VerifiedPill(text: "Verified hotel") }
                        if listing.hotel?.policy == .flexible {
                            Text("Free cancellation")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.primary, in: .capsule)
                        }
                    }
                    .padding(12)
                }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    StarRow(count: listing.hotel?.starRating ?? 0)
                    Text(listing.propertyType.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    if listing.reviewCount > 0 {
                        Text(listing.rating, format: .number.precision(.fractionLength(1)))
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.primary, in: .rect(cornerRadius: 6))
                        Text("\(listing.reviewCount) reviews").font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                Text(listing.title).font(.headline).foregroundStyle(Theme.ink)
                Label(listing.locationLine, systemImage: "mappin").font(.subheadline).foregroundStyle(Theme.muted)
                Divider().padding(.vertical, 2)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(rooms.count) room type\(rooms.count == 1 ? "" : "s") available")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(rooms.isEmpty ? Theme.danger : BadgeTone.success.foreground)
                        if let cheapest {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(Money.naira(cheapest.pricePerNight)).font(.title3.bold()).monospacedDigit().foregroundStyle(Theme.ink)
                                Text("/ night").font(.subheadline).foregroundStyle(Theme.muted)
                            }
                            if stay.hasDates {
                                Text("\(Money.naira(cheapest.quote(nights: stay.nights, rooms: stay.rooms).total)) total · \(stay.rooms) room\(stay.rooms == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.snappy) { router.toggleCompare(listing.id) }
                    } label: {
                        Label(comparing ? "Comparing" : "Compare", systemImage: comparing ? "checkmark.square.fill" : "square")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(comparing ? Theme.primary : Theme.muted)
                            .padding(.horizontal, 10)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: comparing)
                }
            }
            .padding(14)
        }
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .shadow(color: Theme.ink.opacity(0.06), radius: 14, y: 5)
    }
}

/// Compact hotel card for the home carousel.
struct HotelCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 150)
                .overlay { ListingPhoto(name: listing.imageNames.first) }
                .clipped()
                .overlay(alignment: .topTrailing) { FavoriteButton(listingID: listing.id, size: 32).padding(2) }
                .overlay(alignment: .bottomLeading) {
                    StarRow(count: listing.hotel?.starRating ?? 0)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.94), in: .capsule)
                        .padding(10)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title).font(.headline).foregroundStyle(Theme.ink).lineLimit(1)
                PriceText(listing: listing, font: .headline)
                if listing.reviewCount > 0 {
                    RatingLabel(listing: listing).font(.caption)
                } else {
                    Text(listing.locationLine).font(.caption).foregroundStyle(Theme.muted)
                }
            }
            .padding(12)
        }
        .frame(width: 250)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 4)
    }
}

/// Floating tray showing hotels selected for comparison.
struct CompareTray: View {
    let onCompare: () -> Void
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if !router.compareIDs.isEmpty {
            HStack(spacing: 10) {
                HStack(spacing: -10) {
                    ForEach(router.compareIDs, id: \.self) { id in
                        ListingPhoto(name: store.listing(id)?.imageNames.first)
                            .frame(width: 38, height: 38)
                            .clipShape(.circle)
                            .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(router.compareIDs.count) of 3 selected").font(.subheadline.weight(.semibold))
                    Text(router.compareIDs.count < 2 ? "Pick one more to compare" : "Ready to compare").font(.caption).opacity(0.8)
                }
                Spacer()
                Button("Clear") { withAnimation { router.compareIDs = [] } }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Button("Compare", action: onCompare)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.white, in: .capsule)
                    .disabled(router.compareIDs.count < 2)
                    .opacity(router.compareIDs.count < 2 ? 0.6 : 1)
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(Theme.primary, in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Side-by-side comparison of up to three hotels.
struct HotelCompareView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    private var hotels: [Listing] { router.compareIDs.compactMap { store.listing($0) } }

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .top, spacing: 12) {
                    labelsColumn
                    ForEach(hotels) { hotel in
                        column(hotel)
                    }
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("Compare hotels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private let rowTitles = ["Stars", "Guest rating", "From / night", "Room types", "Cancellation", "Check-in", "Pool", "Restaurant", "Breakfast", "Airport shuttle", "Location"]

    private var labelsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 150)
            ForEach(rowTitles, id: \.self) { title in
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(height: 44, alignment: .leading)
            }
        }
        .frame(width: 96)
    }

    private func column(_ hotel: Listing) -> some View {
        let details = hotel.hotel
        let values: [String] = [
            "\(details?.starRating ?? 0)★",
            hotel.reviewCount > 0 ? String(format: "%.1f (%d)", hotel.rating, hotel.reviewCount) : "New",
            Money.naira(details?.lowestRate ?? hotel.price),
            "\(details?.rooms.count ?? 0)",
            details?.policy.title ?? "—",
            details?.checkInTime ?? "—",
            hotel.facilities.contains(.pool) ? "✓" : "—",
            hotel.facilities.contains(.restaurant) ? "✓" : "—",
            hotel.facilities.contains(.breakfast) ? "✓" : "—",
            hotel.facilities.contains(.airportShuttle) ? "✓" : "—",
            hotel.locationLine
        ]
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                ListingPhoto(name: hotel.imageNames.first)
                    .frame(width: 150, height: 92)
                    .clipShape(.rect(cornerRadius: 12))
                Text(hotel.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(2)
            }
            .frame(height: 150, alignment: .top)
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(value == "✓" ? Theme.primary : Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(height: 44, alignment: .leading)
            }
            Button("View hotel") {
                dismiss()
                router.push(.listing(hotel.id))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Theme.primary, in: .capsule)
            .padding(.top, 8)
        }
        .frame(width: 150)
        .padding(12)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cardRadius))
    }
}
