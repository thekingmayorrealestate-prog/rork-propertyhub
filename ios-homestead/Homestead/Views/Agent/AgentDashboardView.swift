import SwiftUI
import Charts

struct DayPoint: Identifiable {
    let id: Int
    let label: String
    let value: Int
}

/// Last-7-days labels ending today, paired with values.
func weekPoints(_ values: [Int]) -> [DayPoint] {
    let cal = Calendar.current
    return (0..<7).map { i in
        let date = cal.date(byAdding: .day, value: i - 6, to: Date()) ?? Date()
        return DayPoint(id: i, label: date.formatted(.dateTime.weekday(.abbreviated)), value: i < values.count ? values[i] : 0)
    }
}

struct AgentDashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showAccount = false
    @State private var showEditor = false
    @State private var chartAppeared = false

    private var weeklyViews: [Int] {
        var totals = Array(repeating: 0, count: 7)
        for listing in store.myListings {
            for (i, v) in listing.weeklyViews.prefix(7).enumerated() { totals[i] += v }
        }
        return totals
    }

    var body: some View {
        let requests = store.incomingRequests
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if store.currentUser?.isVerified == false { verificationBanner }
                statsCard(requests)
                listingsSection
                inquiriesSection(requests)
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
                Text("Agent Dashboard").font(.subheadline.weight(.medium)).foregroundStyle(Theme.muted)
                Text("Welcome back").font(.largeTitle.bold()).foregroundStyle(Theme.ink)
                Text("Here's how your listings are performing this week.")
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
                    Text("Agent").font(.caption2).foregroundStyle(Theme.muted)
                }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Account")
        }
        .padding(.horizontal, 16)
    }

    private var verificationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
            Text("Your profile is awaiting verification. Listings still go through review and can be submitted now.")
                .font(.footnote)
        }
        .foregroundStyle(BadgeTone.warning.foreground)
        .padding(14)
        .background(BadgeTone.warning.background, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func statsCard(_ requests: [Booking]) -> some View {
        let views = weeklyViews.reduce(0, +)
        let inquiries = requests.filter { $0.kind != .shortletBooking }.count
        let bookings = requests.filter { $0.kind == .shortletBooking && $0.status != .declined && $0.status != .cancelled }.count
        return VStack(spacing: 18) {
            HStack(spacing: 0) {
                metric(views, "views")
                Divider().frame(height: 44)
                metric(inquiries, "inquiries")
                Divider().frame(height: 44)
                metric(bookings, "bookings")
            }
            HStack {
                Spacer()
                Text("Last 7 days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.canvas, in: .capsule)
            }
            Chart(weekPoints(weeklyViews)) { point in
                BarMark(
                    x: .value("Day", point.label),
                    y: .value("Views", chartAppeared ? point.value : 0),
                    width: .ratio(0.62)
                )
                .foregroundStyle(Theme.primary.opacity(0.82))
                .cornerRadius(5)
            }
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

    private func metric(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value.formatted())
                .font(.title.bold())
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label).font(.subheadline).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var listingsSection: some View {
        let listings = Array(store.myListings.prefix(3))
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My Listings", actionTitle: "See All") { router.push(.agentListings) }
            VStack(spacing: 0) {
                ForEach(listings) { listing in
                    NavigationLink(value: Route.agentListing(listing.id)) {
                        AgentListingRow(listing: listing)
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
                            Text("Add new listing").font(.headline).foregroundStyle(Theme.ink)
                            Text("Rent, shortlet or sale").font(.subheadline).foregroundStyle(Theme.muted)
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

    private func inquiriesSection(_ requests: [Booking]) -> some View {
        let pending = requests.filter { $0.status == .pending }
        let recent = Array((pending.isEmpty ? requests : pending).prefix(3))
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Inquiries", actionTitle: "See All") { router.push(.agentRequests) }
            VStack(spacing: 0) {
                if recent.isEmpty {
                    Text("No inquiries yet. They'll appear here as soon as someone reaches out.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(recent) { booking in
                    NavigationLink(value: Route.booking(booking.id)) {
                        inquiryRow(booking)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 72)
                }
                NavigationLink(value: Route.messages) {
                    HStack(spacing: 14) {
                        Image(systemName: "bubble.left")
                            .foregroundStyle(Theme.accent)
                            .frame(width: 46, height: 46)
                            .background(Theme.accentSoft, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            let unread = store.unreadMessageCount
                            Text(unread > 0 ? "\(unread) new message\(unread == 1 ? "" : "s")" : "Messages")
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            Text("From potential tenants and buyers").font(.subheadline).foregroundStyle(Theme.muted)
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

    private func inquiryRow(_ booking: Booking) -> some View {
        let user = store.account(booking.userID)
        let action: String
        switch booking.kind {
        case .viewing: action = "wants a viewing"
        case .shortletBooking: action = "requested a stay"
        case .hotelReservation: action = "reserved a room"
        case .rentalInquiry: action = "asked about renting"
        case .purchaseInquiry: action = "asked about buying"
        }
        return HStack(spacing: 14) {
            AvatarView(account: user, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(user?.shortName ?? "Someone") \(action)").font(.headline).foregroundStyle(Theme.ink).lineLimit(1)
                Text("\(store.listing(booking.listingID)?.title ?? "") · \(booking.createdAt.relativeText)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer()
            if booking.status == .pending {
                Circle().fill(Theme.accent).frame(width: 8, height: 8)
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .padding(12)
        .contentShape(.rect)
    }
}

struct AgentListingRow: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 14) {
            ListingPhoto(name: listing.imageNames.first)
                .frame(width: 70, height: 70)
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(listing.title).font(.headline).foregroundStyle(Theme.ink).lineLimit(1)
                Text(listing.propertyType == .land ? "\(listing.sizeSqm) sqm · \(listing.area)" : "\(listing.bedrooms) bed · \(listing.area), \(listing.city)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            StatusBadge(text: listing.status.title, tone: listing.status.tone, showsDot: true)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .padding(10)
        .contentShape(.rect)
    }
}

struct AgentListingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.myListings) { listing in
                    NavigationLink(value: Route.agentListing(listing.id)) { AgentListingRow(listing: listing) }
                        .buttonStyle(.plain)
                    if listing.id != store.myListings.last?.id { Divider().padding(.leading, 96) }
                }
            }
            .card(padding: 4)
            .padding(16)
            if store.myListings.isEmpty {
                ContentUnavailableView("No listings yet", systemImage: "house", description: Text("Add your first property to start receiving inquiries."))
            }
        }
        .screenBackground()
        .navigationTitle("My Listings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add listing")
            }
        }
        .sheet(isPresented: $showEditor) { ListingEditorView(existing: nil) }
    }
}

struct AgentRequestsView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: Filter = .pending

    enum Filter: String, CaseIterable { case pending = "Pending", active = "Active", past = "Past" }

    private var items: [Booking] {
        store.incomingRequests.filter { b in
            switch filter {
            case .pending: b.status == .pending
            case .active: b.status == .confirmed || b.status == .viewingScheduled
            case .past: b.status == .completed || b.status == .declined || b.status == .cancelled
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if items.isEmpty {
                    ContentUnavailableView("Nothing here", systemImage: "tray", description: Text("Requests for your listings will show up here."))
                        .padding(.top, 30)
                } else {
                    VStack(spacing: 0) {
                        ForEach(items) { booking in
                            NavigationLink(value: Route.booking(booking.id)) {
                                BookingRow(booking: booking, showsRequester: true)
                            }
                            .buttonStyle(.plain)
                            if booking.id != items.last?.id { Divider().padding(.leading, 104) }
                        }
                    }
                    .card(padding: 4)
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(store.isHotelOwner ? "Reservations" : "Inquiries & bookings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
