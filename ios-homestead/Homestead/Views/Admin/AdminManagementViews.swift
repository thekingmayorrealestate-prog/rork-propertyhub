import SwiftUI

struct AdminListingsView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: ListingStatus = .pending
    @State private var rejectTarget: Listing?
    @State private var rejectReason = ""

    private var listings: [Listing] {
        store.data.listings.filter { $0.status == filter }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                Picker("Status", selection: $filter) {
                    Text("Pending").tag(ListingStatus.pending)
                    Text("Live").tag(ListingStatus.live)
                    Text("Hidden").tag(ListingStatus.unavailable)
                    Text("Rejected").tag(ListingStatus.rejected)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                if listings.isEmpty {
                    Text("No \(filter.title.lowercased()) listings.").foregroundStyle(Theme.muted)
                }
                ForEach(listings) { listing in
                    NavigationLink(value: Route.listing(listing.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            AgentListingRow(listing: listing)
                            Text("By \(store.account(listing.agentID)?.name ?? "Unknown")\(store.account(listing.agentID)?.isVerified == true ? " · Verified" : " · Unverified") · \(listing.createdAt.relativeText)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .padding(.leading, 10)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if listing.status == .pending || listing.status == .live {
                            Button("Reject") { rejectReason = ""; rejectTarget = listing }.tint(Theme.danger)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if listing.status == .pending || listing.status == .rejected {
                            Button("Approve") { store.approveListing(listing.id) }.tint(Theme.primary)
                        }
                        if listing.status == .live {
                            Button(listing.isFeatured ? "Unfeature" : "Feature") {
                                store.setFeatured(listing.id, featured: !listing.isFeatured)
                            }
                            .tint(Theme.accent)
                        }
                    }
                }
            } footer: {
                Text("Swipe right to approve or feature, left to reject. Tap to review full details.")
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Listing approvals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Reject listing", isPresented: Binding(get: { rejectTarget != nil }, set: { if !$0 { rejectTarget = nil } })) {
            TextField("Reason shown to the agent", text: $rejectReason)
            Button("Reject", role: .destructive) {
                if let target = rejectTarget { store.rejectListing(target.id, reason: rejectReason) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct AdminAgentsView: View {
    @Environment(AppStore.self) private var store
    @State private var role: UserRole

    init(role: UserRole = .agent) {
        _role = State(initialValue: role)
    }

    private var agents: [Account] {
        store.data.accounts.filter { $0.role == role }.sorted { (!$0.isVerified ? 0 : 1, $0.name) < (!$1.isVerified ? 0 : 1, $1.name) }
    }

    var body: some View {
        List {
            Section {
                Picker("Account type", selection: $role) {
                    Text("Agents & landlords").tag(UserRole.agent)
                    Text("Hotel owners").tag(UserRole.hotelOwner)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if agents.isEmpty {
                Text("No accounts yet.").foregroundStyle(Theme.muted)
            }
            ForEach(agents) { agent in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    AvatarView(account: agent, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.name).font(.headline)
                        Text(agent.agencyName ?? "—").font(.subheadline).foregroundStyle(Theme.muted)
                        Text("\(agent.email) · \(agent.phone)").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    StatusBadge(text: agent.isVerified ? (role == .hotelOwner ? "Approved" : "Verified") : "Pending", tone: agent.isVerified ? .success : .warning)
                }
                HStack {
                    Text("\(store.data.listings.filter { $0.agentID == agent.id }.count) \(role == .hotelOwner ? "hotels" : "listings") · joined \(agent.createdAt.formatted(.dateTime.month(.abbreviated).year()))")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button(agent.isVerified ? "Revoke" : (role == .hotelOwner ? "Approve" : "Verify")) {
                        store.setAgentVerified(agent.id, verified: !agent.isVerified)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(agent.isVerified ? Theme.muted : Theme.primary)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(role == .hotelOwner ? "Hotel-owner applications" : "Agents & landlords")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct AdminUsersView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""

    private var users: [Account] {
        let all = store.data.accounts.filter { $0.role != .admin }.sorted { $0.createdAt > $1.createdAt }
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedStandardContains(query) || $0.email.localizedStandardContains(query) }
    }

    var body: some View {
        List(users) { user in
            HStack(spacing: 12) {
                AvatarView(account: user, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name).font(.headline).strikethrough(user.isSuspended)
                    Text(user.email).font(.caption).foregroundStyle(Theme.muted)
                    Text("\(user.role.label) · \(store.data.bookings.filter { $0.userID == user.id }.count) requests")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                if user.isSuspended {
                    StatusBadge(text: "Suspended", tone: .danger)
                }
            }
            .swipeActions {
                Button(user.isSuspended ? "Reinstate" : "Suspend") {
                    store.setSuspended(user.id, suspended: !user.isSuspended)
                }
                .tint(user.isSuspended ? Theme.primary : Theme.danger)
            }
            .contextMenu {
                Button(user.isSuspended ? "Reinstate account" : "Suspend account", systemImage: user.isSuspended ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark") {
                    store.setSuspended(user.id, suspended: !user.isSuspended)
                }
            }
        }
        .searchable(text: $query, prompt: "Search users")
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Users")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct AdminBookingsView: View {
    @Environment(AppStore.self) private var store
    @State private var segment: BookingSegment = .shortlets

    private var items: [Booking] {
        store.data.bookings.filter { $0.category == segment.category }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Type", selection: $segment) {
                    ForEach(BookingSegment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if items.isEmpty {
                    ContentUnavailableView("No requests", systemImage: "tray")
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
        .navigationTitle("Bookings & inquiries")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct AdminReportsView: View {
    @Environment(AppStore.self) private var store

    private var reports: [ListingReport] {
        store.data.reports.sorted { (!$0.isResolved ? 0 : 1, $1.createdAt) < (!$1.isResolved ? 0 : 1, $0.createdAt) }
    }

    var body: some View {
        Group {
            if reports.isEmpty {
                ContentUnavailableView("No reports", systemImage: "flag", description: Text("Reported listings will appear here."))
            } else {
                List(reports) { report in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(report.reason).font(.headline)
                            Spacer()
                            StatusBadge(text: report.isResolved ? "Resolved" : "Open", tone: report.isResolved ? .neutral : .warning)
                        }
                        if let listing = store.listing(report.listingID) {
                            NavigationLink(value: Route.listing(listing.id)) {
                                Text(listing.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                            }
                        }
                        if !report.details.isEmpty {
                            Text(report.details).font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        Text("Reported by \(store.account(report.reporterID)?.name ?? "user") · \(report.createdAt.relativeText)")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        if !report.isResolved {
                            HStack {
                                Button("Dismiss") { store.resolveReport(report.id, takeDown: false) }
                                    .buttonStyle(.bordered)
                                Button("Take down listing") { store.resolveReport(report.id, takeDown: true) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Theme.danger)
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .navigationTitle("Reported listings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct AdminTransactionsView: View {
    @Environment(AppStore.self) private var store

    private var payments: [Payment] {
        store.data.payments.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        let paid = payments.filter { $0.status == .paid }
        List {
            Section {
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(Money.compact(paid.reduce(0) { $0 + $1.total })).font(.title2.bold()).monospacedDigit()
                        Text("Gross volume").font(.caption).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 40)
                    VStack(spacing: 2) {
                        Text(Money.naira(paid.reduce(0) { $0 + $1.serviceFee })).font(.title2.bold()).monospacedDigit()
                            .minimumScaleFactor(0.6)
                        Text("Platform fees").font(.caption).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 6)
            }
            Section("All transactions") {
                ForEach(payments) { payment in
                    NavigationLink(value: Route.receipt(payment.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(Money.naira(payment.total)).font(.headline).monospacedDigit()
                                Spacer()
                                StatusBadge(text: payment.status.title, tone: payment.status.tone)
                            }
                            Text("\(store.listing(payment.listingID)?.title ?? "Listing") · \(store.account(payment.userID)?.name ?? "")")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                            Text("#\(payment.reference) · \(payment.method.title) · \(payment.createdAt.formatted(.dateTime.day().month(.abbreviated).year()))")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .swipeActions {
                        if payment.status == .paid {
                            Button("Refund") { store.refundPayment(payment.id) }.tint(BadgeTone.info.foreground)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
