import SwiftUI
import PhotosUI

/// Create or edit a listing. Submissions go to admin review before becoming public.
struct ListingEditorView: View {
    let existing: Listing?

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Listing = .blank(agentID: UUID())
    @State private var priceText = ""
    @State private var sizeText = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var submitted = false
    @State private var editingRoom: RoomType?
    @State private var isAddingRoom = false

    private var isHotelMode: Bool { draft.category == .hotel }

    private var isValid: Bool {
        let hasPrice = isHotelMode ? !(draft.hotel?.rooms.isEmpty ?? true) : (Int(priceText.filter(\.isNumber)) ?? 0) > 0
        return !draft.title.trimmingCharacters(in: .whitespaces).isEmpty &&
            !draft.area.trimmingCharacters(in: .whitespaces).isEmpty &&
            hasPrice &&
            !draft.imageNames.isEmpty &&
            draft.summary.count >= 20
    }

    private var hotelBinding: Binding<HotelDetails> {
        Binding(get: { draft.hotel ?? .blank() }, set: { draft.hotel = $0 })
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    BookingSuccessView(
                        title: existing == nil ? "Submitted for review" : "Changes submitted",
                        message: isHotelMode
                            ? "Our team reviews every hotel before it's published. We'll notify you as soon as guests can book."
                            : "Our team reviews every listing to keep Homestead trustworthy. We'll notify you as soon as it's live.",
                        detail: draft.title
                    ) { dismiss() }
                } else {
                    form
                }
            }
            .navigationTitle(submitted ? "" : (existing == nil ? (isHotelMode ? "New hotel" : "New listing") : (isHotelMode ? "Edit hotel" : "Edit listing")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") { submit() }
                            .fontWeight(.semibold)
                            .disabled(!isValid)
                    }
                }
            }
        }
        .interactiveDismissDisabled(!submitted)
        .onAppear(perform: load)
    }

    private var form: some View {
        Form {
            Section {
                photosRow
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                    Label(isLoadingPhotos ? "Adding photos…" : "Add photos", systemImage: "photo.badge.plus")
                }
                .disabled(isLoadingPhotos)
            } header: {
                Text("Photos")
            } footer: {
                Text("Add at least one bright, high-quality photo. The first photo is your cover.")
            }

            if isHotelMode {
                hotelSections
            } else {
                propertySections
            }

            Section("Location") {
                Picker("City", selection: $draft.city) {
                    ForEach(SeedData.cities, id: \.self) { Text($0).tag($0) }
                }
                TextField("Area / neighbourhood, e.g. Lekki Phase 1", text: $draft.area)
                TextField(isHotelMode ? "Street address" : "Street address (shared after acceptance)", text: $draft.address)
            }

            Section("Facilities") {
                ForEach(Facility.options(for: draft.category)) { facility in
                    Toggle(isOn: Binding(
                        get: { draft.facilities.contains(facility) },
                        set: { on in
                            if on { draft.facilities.append(facility) } else { draft.facilities.removeAll { $0 == facility } }
                        }
                    )) {
                        Label(facility.title, systemImage: facility.symbol)
                    }
                }
            }

            Section {
                TextField(isHotelMode ? "Describe the hotel, dining, location and highlights" : "Describe the property, neighbourhood and highlights", text: $draft.summary, axis: .vertical)
                    .lineLimit(4...10)
            } header: {
                Text("Description")
            } footer: {
                Text("At least 20 characters.")
            }

            if !isHotelMode {
                Section(draft.category == .sale ? "Title documents & terms" : "Rental terms") {
                    TextField(draft.category == .sale ? "e.g. C of O, Governor's consent, payment plan" : "Lease length, deposits, house rules", text: $draft.terms, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
        }
        .tint(Theme.primary)
        .sheet(item: $editingRoom) { room in
            RoomEditorSheet(existing: room) { updated in
                if let idx = draft.hotel?.rooms.firstIndex(where: { $0.id == updated.id }) { draft.hotel?.rooms[idx] = updated }
            }
        }
        .sheet(isPresented: $isAddingRoom) {
            RoomEditorSheet(existing: nil) { room in
                if draft.hotel == nil { draft.hotel = .blank() }
                draft.hotel?.rooms.append(room)
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            isLoadingPhotos = true
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let name = ImageStore.shared.save(image) {
                        draft.imageNames.append(name)
                    }
                }
                pickerItems = []
                isLoadingPhotos = false
            }
        }
    }

    @ViewBuilder
    private var hotelSections: some View {
        Section("Hotel") {
            TextField("Hotel name, e.g. The Eko Grand", text: $draft.title)
            Picker("Type", selection: $draft.propertyType) {
                ForEach(PropertyType.hotelTypes) { Text($0.title).tag($0) }
            }
            Stepper(value: hotelBinding.starRating, in: 1...5) {
                HStack {
                    Text("Star rating")
                    Spacer()
                    StarRow(count: hotelBinding.wrappedValue.starRating, size: .subheadline)
                }
            }
        }
        Section {
            ForEach(draft.hotel?.rooms ?? []) { room in
                Button {
                    editingRoom = room
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(room.name).foregroundStyle(Theme.ink)
                            Text("\(room.kind.title) · sleeps \(room.capacity) · \(room.totalRooms) rooms").font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(Money.naira(room.pricePerNight)).monospacedDigit().foregroundStyle(Theme.ink)
                    }
                }
            }
            .onDelete { offsets in draft.hotel?.rooms.remove(atOffsets: offsets) }
            Button {
                isAddingRoom = true
            } label: {
                Label("Add room type", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Rooms & nightly rates")
        } footer: {
            Text("Add each room category (single, double, suite…) with its rate and how many rooms you have. Guests can only book rooms that are free on every night of their stay.")
        }
        Section("Policies") {
            TextField("Check-in time", text: hotelBinding.checkInTime)
            TextField("Check-out time", text: hotelBinding.checkOutTime)
            Picker("Cancellation", selection: hotelBinding.policy) {
                ForEach(CancellationPolicy.allCases) { Text($0.title).tag($0) }
            }
            Text(hotelBinding.wrappedValue.policy.summary).font(.footnote).foregroundStyle(Theme.muted)
            TextField("Check-in requirements", text: hotelBinding.checkInRequirements, axis: .vertical).lineLimit(2...5)
        }
    }

    @ViewBuilder
    private var propertySections: some View {
            Section("Listing") {
                TextField("Title, e.g. Lekki Sky Loft", text: $draft.title)
                Picker("Listing type", selection: $draft.category) {
                    ForEach(ListingCategory.propertyCategories) { Text($0 == .sale ? "For sale" : $0.title).tag($0) }
                }
                .onChange(of: draft.category) { _, newValue in
                    switch newValue {
                    case .shortlet, .hotel: draft.priceUnit = .night
                    case .sale: draft.priceUnit = .total
                    case .rent: if draft.priceUnit != .month { draft.priceUnit = .year }
                    }
                }
                Picker("Property type", selection: $draft.propertyType) {
                    ForEach(PropertyType.propertyTypes) { Text($0.title).tag($0) }
                }
            }

            Section("Price") {
                HStack {
                    Text("₦")
                    TextField("Amount", text: $priceText).keyboardType(.numberPad)
                }
                if draft.category == .rent {
                    Picker("Billed", selection: $draft.priceUnit) {
                        Text("Per year").tag(PriceUnit.year)
                        Text("Per month").tag(PriceUnit.month)
                    }
                    .pickerStyle(.segmented)
                } else {
                    LabeledContent("Billed", value: draft.priceUnit.title)
                }
            }

            Section("Specifications") {
                if draft.propertyType != .land {
                    Stepper("Bedrooms: \(draft.bedrooms)", value: $draft.bedrooms, in: 0...12)
                    Stepper("Bathrooms: \(draft.bathrooms)", value: $draft.bathrooms, in: 0...12)
                }
                if draft.category == .shortlet {
                    Stepper("Sleeps: \(draft.sleeps)", value: $draft.sleeps, in: 1...20)
                }
                HStack {
                    Text("Size")
                    Spacer()
                    TextField("sqm", text: $sizeText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text("sqm").foregroundStyle(Theme.muted)
                }
            }
    }

    @ViewBuilder
    private var photosRow: some View {
        if draft.imageNames.isEmpty {
            HStack {
                Image(systemName: "photo.on.rectangle.angled").font(.title2).foregroundStyle(Theme.muted)
                Text("No photos yet").foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(draft.imageNames.enumerated()), id: \.element) { index, name in
                        ListingPhoto(name: name)
                            .frame(width: 96, height: 76)
                            .clipShape(.rect(cornerRadius: 10))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    withAnimation { draft.imageNames.removeAll { $0 == name } }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                                .accessibilityLabel("Remove photo")
                            }
                            .overlay(alignment: .bottomLeading) {
                                if index == 0 {
                                    Text("Cover")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.primary, in: .capsule)
                                        .padding(5)
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func load() {
        if let existing {
            draft = existing
            priceText = String(existing.price)
            sizeText = String(existing.sizeSqm)
        } else if let id = store.currentUserID {
            draft = .blank(agentID: id)
            sizeText = "120"
            if store.isHotelOwner {
                draft.category = .hotel
                draft.propertyType = .hotel
                draft.priceUnit = .night
                draft.hotel = .blank()
            }
        }
    }

    private func submit() {
        if isHotelMode {
            draft.terms = draft.hotel?.policy.summary ?? ""
        } else {
            draft.price = Int(priceText.filter(\.isNumber)) ?? 0
        }
        draft.sizeSqm = Int(sizeText.filter(\.isNumber)) ?? 0
        if draft.address.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.address = "\(draft.area), \(draft.city)"
        }
        if draft.propertyType == .land || isHotelMode {
            draft.bedrooms = 0
            draft.bathrooms = 0
        }
        if existing == nil || existing?.city != draft.city || existing?.area != draft.area {
            let center = SeedData.cityCenters[draft.city] ?? (6.455, 3.42)
            draft.latitude = center.0 + Double.random(in: -0.03...0.03)
            draft.longitude = center.1 + Double.random(in: -0.04...0.04)
        }
        if existing == nil {
            store.submitListing(draft)
        } else {
            store.updateListing(draft)
        }
        withAnimation(.spring) { submitted = true }
    }
}
