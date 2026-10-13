import SwiftUI
import MapKit

struct ListingDetailView: View {
    let listingID: UUID

    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var photoIndex = 0
    @State private var showBooking = false
    @State private var inquiryKind: RequestKind?
    @State private var showFacilities = false
    @State private var showReport = false
    @State private var showReject = false
    @State private var rejectReason = ""
    @State private var expandedAbout = false
    @State private var errorMessage: String?
    @State private var didRecordView = false
    @State private var reserveRoom: RoomType?

    var body: some View {
        Group {
            if let listing = store.listing(listingID) {
                content(listing)
            } else {
                ContentUnavailableView("Listing unavailable", systemImage: "house.slash", description: Text("This listing has been removed."))
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .tabBar)
    }

    private func content(_ listing: Listing) -> some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if listing.status != .live {
                    statusBanner(listing)
                }
                gallery(listing)
                titleBlock(listing)
                specsCard(listing)
                if !listing.facilities.isEmpty { facilities(listing) }
                agentCard(listing)
                about(listing)
                if listing.category == .shortlet && !store.isOwner(listing) && listing.status == .live {
                    datesCard
                }
                if listing.isHotel {
                    HotelRoomsSection(listing: listing) { room in
                        requireAuth { reserveRoom = room }
                    }
                    .id("rooms")
                    if let hotel = listing.hotel { HotelPoliciesCard(hotel: hotel) }
                }
                ReviewsSection(listing: listing)
                mapCard(listing)
                if store.isSignedIn && !store.isOwner(listing) && !store.isAdmin {
                    Button {
                        showReport = true
                    } label: {
                        Label("Report this listing", systemImage: "flag")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            actionBar(listing) {
                withAnimation(.snappy) { proxy.scrollTo("rooms", anchor: .top) }
            }
        }
        }
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if listing.isHotel && listing.status == .live {
                    Button {
                        router.toggleCompare(listing.id)
                    } label: {
                        Image(systemName: router.compareIDs.contains(listing.id) ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                    }
                    .accessibilityLabel(router.compareIDs.contains(listing.id) ? "Remove from compare" : "Add to compare")
                }
                ShareLink(item: "\(listing.title) – \(listing.priceText) \(listing.priceUnit.suffix) in \(listing.locationLine). Found on Homestead.") {
                    Image(systemName: "square.and.arrow.up")
                }
                Button {
                    guard store.isSignedIn else { router.presentAuth(); return }
                    store.toggleFavorite(listing.id)
                } label: {
                    Image(systemName: store.isFavorite(listing.id) ? "heart.fill" : "heart")
                        .foregroundStyle(store.isFavorite(listing.id) ? Theme.accent : Theme.ink)
                }
                .accessibilityLabel("Save")
            }
        }
        .sheet(isPresented: $showBooking) { BookingRequestSheet(listing: listing) }
        .sheet(item: $reserveRoom) { room in HotelReservationSheet(listing: listing, roomID: room.id) }
        .sheet(item: $inquiryKind) { kind in InquirySheet(listing: listing, initialKind: kind) }
        .sheet(isPresented: $showFacilities) { FacilitiesSheet(facilities: listing.facilities) }
        .sheet(isPresented: $showReport) { ReportSheet(listing: listing) }
        .alert("Reject listing", isPresented: $showReject) {
            TextField("Reason shown to the agent", text: $rejectReason)
            Button("Reject", role: .destructive) { store.rejectListing(listing.id, reason: rejectReason) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            guard !didRecordView else { return }
            didRecordView = true
            if listing.status == .live { store.recordView(listing.id) }
        }
    }

    // MARK: Sections

    private func statusBanner(_ listing: Listing) -> some View {
        HStack(spacing: 10) {
            Image(systemName: listing.status == .rejected ? "xmark.octagon.fill" : "clock.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.status.title).font(.subheadline.weight(.semibold))
                if let reason = listing.rejectionReason, listing.status == .rejected {
                    Text(reason).font(.footnote)
                } else if listing.status == .pending {
                    Text("Only you and administrators can see this listing until it's approved.").font(.footnote)
                } else {
                    Text("This listing is currently hidden from search.").font(.footnote)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(listing.status.tone.foreground)
        .padding(14)
        .background(listing.status.tone.background, in: .rect(cornerRadius: 14))
    }

    private func gallery(_ listing: Listing) -> some View {
        let images = listing.imageNames.isEmpty ? [""] : listing.imageNames
        return VStack(spacing: 8) {
            TabView(selection: $photoIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, name in
                    ListingPhoto(name: name).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 270)
            .clipShape(.rect(cornerRadius: Theme.cardRadius))
            .overlay(alignment: .bottomLeading) {
                Text("\(photoIndex + 1) / \(images.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.5), in: .capsule)
                    .padding(12)
            }
            if images.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, name in
                            Button {
                                withAnimation(.snappy) { photoIndex = index }
                            } label: {
                                ListingPhoto(name: name)
                                    .frame(width: 84, height: 62)
                                    .clipShape(.rect(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Theme.accent, lineWidth: photoIndex == index ? 2.5 : 0)
                                    )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func titleBlock(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(categoryTag(listing))
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.accent)
                Text("·").foregroundStyle(Theme.muted)
                Text(listing.propertyType.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                if let stars = listing.hotel?.starRating {
                    StarRow(count: stars)
                }
            }
            Text(listing.title)
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.ink)
            Label(listing.address, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            if listing.reviewCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Theme.accent)
                    Text(listing.rating, format: .number.precision(.fractionLength(1))).foregroundStyle(Theme.ink)
                    Text("(\(listing.reviewCount) reviews)").foregroundStyle(Theme.muted)
                }
                .font(.subheadline)
            }
        }
    }

    private func categoryTag(_ listing: Listing) -> String {
        switch listing.category {
        case .sale: "FOR SALE"
        case .rent: "FOR RENT"
        case .shortlet: "SHORTLET"
        case .hotel: "HOTEL"
        }
    }

    private func specsCard(_ listing: Listing) -> some View {
        HStack(spacing: 0) {
            if let hotel = listing.hotel, listing.isHotel {
                spec("star", "\(hotel.starRating)-star")
                Divider().frame(height: 36)
                spec("bed.double", "\(hotel.rooms.count) room types")
                Divider().frame(height: 36)
                spec("clock", "In \(hotel.checkInTime)")
            } else if listing.propertyType == .land {
                spec("square.dashed", "\(listing.sizeSqm.formatted()) sqm")
                Divider().frame(height: 36)
                spec("doc.text", "Titled land")
            } else {
                spec("bed.double", "\(listing.bedrooms) bd")
                Divider().frame(height: 36)
                spec("bathtub", "\(listing.bathrooms) ba")
                Divider().frame(height: 36)
                if listing.category == .shortlet {
                    spec("person.2", "Sleeps \(listing.sleeps)")
                } else {
                    spec("square.dashed", "\(listing.sizeSqm.formatted()) sqm")
                }
            }
        }
        .card(padding: 14)
    }

    private func spec(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Theme.ink)
            Text(text).font(.footnote.weight(.medium)).foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private func facilities(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Facilities").font(.title3.bold()).foregroundStyle(Theme.ink)
                Spacer()
                if listing.facilities.count > 4 {
                    Button("See all \(listing.facilities.count)") { showFacilities = true }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(listing.facilities) { facility in
                        Label(facility.title, systemImage: facility.symbol)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(Theme.surface, in: .rect(cornerRadius: 12))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func agentCard(_ listing: Listing) -> some View {
        let agent = store.account(listing.agentID)
        HStack(spacing: 14) {
            AvatarView(account: agent, size: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(agent?.name ?? "Agent").font(.headline).foregroundStyle(Theme.ink)
                if agent?.isVerified == true {
                    Label(listing.isHotel ? "Verified hotel" : "Verified agent", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.primary)
                } else {
                    Text("Verification pending").font(.subheadline).foregroundStyle(Theme.muted)
                }
                if let agency = agent?.agencyName {
                    Text(agency).font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            if !store.isOwner(listing) {
                Button {
                    startChat(listing)
                } label: {
                    Label("Message", systemImage: "bubble.left.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .overlay(Capsule().strokeBorder(Theme.primary, lineWidth: 1.5))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .card()
    }

    private func about(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(listing.isHotel ? "About this hotel" : "About this property").font(.title3.bold()).foregroundStyle(Theme.ink)
            Text(listing.summary)
                .font(.body)
                .foregroundStyle(Theme.muted)
                .lineLimit(expandedAbout ? nil : 3)
            if !listing.terms.isEmpty && expandedAbout && !listing.isHotel {
                Text(listing.category == .sale ? "Title & terms" : "Terms")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 4)
                Text(listing.terms).font(.body).foregroundStyle(Theme.muted)
            }
            Button(expandedAbout ? "Show less" : (listing.isHotel ? "Read more" : "Read more & terms")) {
                withAnimation(.snappy) { expandedAbout.toggle() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select dates").font(.title3.bold()).foregroundStyle(Theme.ink)
            Button {
                requireAuth { showBooking = true }
            } label: {
                HStack {
                    dateCell("Check in")
                    Divider().frame(height: 34)
                    dateCell("Check out")
                }
                .card(padding: 14)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func dateCell(_ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar").foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(Theme.muted)
                Text("Add date").font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
            }
            Spacer()
        }
    }

    private func mapCard(_ listing: Listing) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: listing.latitude, longitude: listing.longitude)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Location").font(.title3.bold()).foregroundStyle(Theme.ink)
            Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))), interactionModes: []) {
                Marker(listing.title, systemImage: listing.isHotel ? "bed.double.fill" : "house.fill", coordinate: coordinate)
                    .tint(Theme.primary)
            }
            .frame(height: 170)
            .clipShape(.rect(cornerRadius: Theme.cardRadius))
            Text(listing.isHotel ? listing.address : "Exact address shared after your request is accepted.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: Action bar

    @ViewBuilder
    private func actionBar(_ listing: Listing, showRooms: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            if store.isAdmin && listing.status == .pending {
                Button("Reject") { rejectReason = ""; showReject = true }
                    .buttonStyle(SecondaryButtonStyle(tint: Theme.danger))
                Button("Approve") { store.approveListing(listing.id) }
                    .buttonStyle(PrimaryButtonStyle())
            } else if store.isOwner(listing) {
                VStack(alignment: .leading, spacing: 2) {
                    PriceText(listing: listing)
                    StatusBadge(text: listing.status.title, tone: listing.status.tone, showsDot: true)
                }
                Spacer()
                NavigationLink(value: Route.agentListing(listing.id)) {
                    Text("Manage listing")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 190)
            } else if listing.status != .live {
                Text("This listing isn't accepting requests right now.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 54)
            } else {
                PriceText(listing: listing, font: .title2.bold())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Spacer(minLength: 8)
                switch listing.category {
                case .shortlet:
                    Button("Request to book") { requireAuth { showBooking = true } }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 200)
                case .hotel:
                    Button("Select a room", action: showRooms)
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 190)
                case .rent:
                    Button("Send inquiry") { requireAuth { inquiryKind = .rentalInquiry } }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 190)
                case .sale:
                    Button("Request viewing") { requireAuth { inquiryKind = .viewing } }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 200)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.06), radius: 10, y: -2)
                .ignoresSafeArea()
        }
    }

    private func requireAuth(_ action: () -> Void) {
        guard store.isSignedIn else {
            router.presentAuth()
            return
        }
        action()
    }

    private func startChat(_ listing: Listing) {
        guard store.isSignedIn else { router.presentAuth(); return }
        do {
            let threadID = try store.openThread(for: listing)
            router.push(.chat(threadID))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FacilitiesSheet: View {
    let facilities: [Facility]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(facilities) { facility in
                Label(facility.title, systemImage: facility.symbol)
                    .foregroundStyle(Theme.ink)
            }
            .navigationTitle("Facilities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct ReportSheet: View {
    let listing: Listing

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "Photos don't match"
    @State private var details = ""
    @State private var sent = false

    private let reasons = ["Photos don't match", "Wrong price", "Suspected scam", "Already rented or sold", "Inappropriate content", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $reason) {
                        ForEach(reasons, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Details (optional)") {
                    TextField("Tell us more", text: $details, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle("Report listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        try? store.report(listingID: listing.id, reason: reason, details: details)
                        sent = true
                    }
                }
            }
            .alert("Thanks for letting us know", isPresented: $sent) {
                Button("Done") { dismiss() }
            } message: {
                Text("Our team will review this listing within 24 hours.")
            }
        }
    }
}
