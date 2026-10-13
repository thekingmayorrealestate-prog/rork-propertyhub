import SwiftUI
import MapKit

struct SearchView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var showMap = false
    @State private var showFilters = false
    @State private var selectedListingID: UUID?
    @State private var camera: MapCameraPosition = .automatic

    private var results: [Listing] { store.search(router.filters) }

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            categoryBar
            if showMap {
                mapContent
            } else {
                listContent
            }
        }
        .screenBackground()
        .navigationTitle("Search")
        .searchable(text: $router.filters.query, isPresented: $router.isSearchFocused, prompt: "Homes, hotels, Lekki, Abuja…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $router.filters.sort) {
                        ForEach(SortOption.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) { showMap.toggle() }
                } label: {
                    Image(systemName: showMap ? "list.bullet" : "map")
                }
                .accessibilityLabel(showMap ? "Show list" : "Show map")
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(filters: $router.filters) {}
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button {
                    showFilters = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Filters")
                        if router.filters.activeCount > 0 {
                            Text("\(router.filters.activeCount)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Theme.accent, in: .circle)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Theme.surface, in: .capsule)
                    .overlay(Capsule().strokeBorder(Theme.hairline))
                }
                .buttonStyle(PressableButtonStyle())

                chip("All", selected: router.filters.category == nil) { router.filters.category = nil }
                ForEach(ListingCategory.allCases) { category in
                    chip(category.title, selected: router.filters.category == category) { router.filters.category = category }
                }
            }
            .padding(.vertical, 10)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? .white : Theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(selected ? Theme.primary : Theme.surface, in: .capsule)
        }
        .buttonStyle(PressableButtonStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("\(results.count) result\(results.count == 1 ? "" : "s")" + (router.filters.hasDates ? " available · \(router.filters.nights) night\(router.filters.nights == 1 ? "" : "s")" : ""))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.numericText())
                ForEach(results) { listing in
                    NavigationLink(value: Route.listing(listing.id)) {
                        ListingRow(listing: listing)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        if listing.isHotel && router.filters.hasDates {
                            router.hotelStay.checkIn = router.filters.checkIn
                            router.hotelStay.checkOut = router.filters.checkOut
                            router.hotelStay.guests = router.filters.guests
                            router.hotelStay.rooms = router.filters.rooms
                        }
                    })
                }
                if results.isEmpty {
                    ContentUnavailableView {
                        Label("No matches", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try another area or loosen your filters.")
                    } actions: {
                        Button("Clear filters") {
                            let category = router.filters.category
                            router.filters = SearchFilters()
                            router.filters.category = category
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 200)
                    }
                    .padding(.top, 30)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var mapContent: some View {
        Map(position: $camera) {
            ForEach(results) { listing in
                Annotation(listing.title, coordinate: CLLocationCoordinate2D(latitude: listing.latitude, longitude: listing.longitude), anchor: .bottom) {
                    Button {
                        withAnimation(.snappy) { selectedListingID = listing.id }
                    } label: {
                        Text(listing.priceText)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(selectedListingID == listing.id ? .white : Theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedListingID == listing.id ? Theme.primary : Theme.surface, in: .capsule)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapCompass() }
        .overlay(alignment: .bottom) {
            if let id = selectedListingID, let listing = results.first(where: { $0.id == id }) {
                NavigationLink(value: Route.listing(listing.id)) {
                    ListingRow(listing: listing)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: router.filters) { _, _ in
            selectedListingID = nil
            camera = .automatic
        }
    }
}

struct FilterSheet: View {
    @Binding var filters: SearchFilters
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = SearchFilters()
    @State private var minPriceText = ""
    @State private var maxPriceText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Looking to", selection: $draft.category) {
                        Text("Any").tag(ListingCategory?.none)
                        ForEach(ListingCategory.allCases) { Text($0.title).tag(Optional($0)) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: draft.category) { _, _ in
                        draft.types = draft.types.filter { PropertyType.types(for: draft.category).contains($0) }
                        draft.facilities = draft.facilities.filter { Facility.options(for: draft.category).contains($0) }
                    }
                }
                if draft.category == nil || draft.category == .shortlet || draft.category == .hotel {
                    Section {
                        Toggle("Only show available for my dates", isOn: Binding(
                            get: { draft.checkIn != nil },
                            set: { on in
                                if on {
                                    let stay = SearchFilters.defaultStay()
                                    draft.checkIn = stay.checkIn
                                    draft.checkOut = stay.checkOut
                                } else {
                                    draft.checkIn = nil
                                    draft.checkOut = nil
                                }
                            }
                        ))
                        if let checkIn = draft.checkIn {
                            DatePicker("Check in", selection: Binding(get: { checkIn }, set: { newValue in
                                draft.checkIn = newValue
                                if (draft.checkOut ?? newValue) <= newValue { draft.checkOut = Calendar.current.date(byAdding: .day, value: 1, to: newValue) }
                            }), in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                            DatePicker("Check out", selection: Binding(get: { draft.checkOut ?? checkIn }, set: { draft.checkOut = $0 }),
                                       in: (Calendar.current.date(byAdding: .day, value: 1, to: checkIn) ?? checkIn)..., displayedComponents: .date)
                        }
                        Stepper("Guests: \(draft.guests)", value: $draft.guests, in: 1...20)
                        if draft.category == .hotel {
                            Stepper("Rooms: \(draft.rooms)", value: $draft.rooms, in: 1...10)
                        }
                    } header: {
                        Text("Dates & guests")
                    } footer: {
                        Text("Availability is checked against existing bookings and room inventory.")
                    }
                }
                if draft.category == .hotel {
                    Section("Room type") {
                        Picker("Room type", selection: $draft.roomKind) {
                            Text("Any").tag(RoomKind?.none)
                            ForEach(RoomKind.allCases) { Text($0.title).tag(Optional($0)) }
                        }
                    }
                }
                Section("Location") {
                    Picker("City", selection: $draft.city) {
                        Text("Anywhere").tag(String?.none)
                        ForEach(SeedData.cities, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                }
                Section(draft.category == .hotel || draft.category == .shortlet ? "Budget per night (₦)" : "Price range (₦)") {
                    TextField("Minimum", text: $minPriceText).keyboardType(.numberPad)
                    TextField("Maximum", text: $maxPriceText).keyboardType(.numberPad)
                }
                if draft.category != .hotel {
                    Section("Bedrooms") {
                        Picker("Minimum bedrooms", selection: $draft.minBedrooms) {
                            Text("Any").tag(0)
                            ForEach(1...4, id: \.self) { Text($0 == 4 ? "4+" : "\($0)+").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section(draft.category == .hotel ? "Accommodation type" : "Property type") {
                    ForEach(PropertyType.types(for: draft.category)) { type in
                        Toggle(type.title, isOn: Binding(
                            get: { draft.types.contains(type) },
                            set: { on in if on { draft.types.insert(type) } else { draft.types.remove(type) } }
                        ))
                    }
                }
                Section("Facilities") {
                    ForEach(Facility.options(for: draft.category)) { facility in
                        Toggle(isOn: Binding(
                            get: { draft.facilities.contains(facility) },
                            set: { on in if on { draft.facilities.insert(facility) } else { draft.facilities.remove(facility) } }
                        )) {
                            Label(facility.title, systemImage: facility.symbol)
                        }
                    }
                }
                Section {
                    Toggle(draft.category == .hotel ? "Verified hotels only" : "Verified partners only", isOn: $draft.verifiedOnly)
                }
            }
            .tint(Theme.primary)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        let query = draft.query
                        draft = SearchFilters()
                        draft.query = query
                        minPriceText = ""
                        maxPriceText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        draft.minPrice = Int(minPriceText.filter(\.isNumber))
                        draft.maxPrice = Int(maxPriceText.filter(\.isNumber))
                        filters = draft
                        dismiss()
                        onApply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            draft = filters
            minPriceText = filters.minPrice.map(String.init) ?? ""
            maxPriceText = filters.maxPrice.map(String.init) ?? ""
        }
    }
}
