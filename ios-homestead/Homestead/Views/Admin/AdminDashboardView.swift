import SwiftUI
import Charts

struct AdminDashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showAccount = false
    @State private var showReset = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let stats = store.adminStats
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                LazyVGrid(columns: columns, spacing: 12) {
                    statTile("\(stats.users)", "Registered users", "person.2.fill", .adminUsers)
                    statTile("\(stats.activeListings)", "Active listings", "house.fill", .adminListings)
                    statTile("\(stats.hotelReservations)", "Hotel reservations", "bed.double.fill", .adminBookings)
                    statTile("\(stats.shortletBookings)", "Shortlet bookings", "suitcase.rolling.fill", .adminBookings)
                    statTile("\(stats.rentalInquiries)", "Rental inquiries", "key.fill", .adminBookings)
                    statTile("\(stats.saleInquiries)", "Sales inquiries", "tag.fill", .adminBookings)
                    statTile("\(stats.approvedAgents)/\(stats.agents)", "Verified agents", "checkmark.seal.fill", .adminAgents)
                    statTile(Money.compact(stats.revenue), "Platform fees", "banknote.fill", .adminTransactions)
                }
                .padding(.horizontal, 16)

                activityCard

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Manage")
                    VStack(spacing: 0) {
                        adminRow("checkmark.rectangle.stack", "Listing approvals", count: stats.pendingListings, route: .adminListings)
                        Divider().padding(.leading, 52)
                        adminRow("person.badge.shield.checkmark", "Agents & landlords", count: store.data.accounts.filter { $0.role == .agent && !$0.isVerified }.count, route: .adminAgents)
                        Divider().padding(.leading, 52)
                        adminRow("bed.double", "Hotel-owner applications", count: stats.pendingHotelOwners, route: .adminHotelOwners)
                        Divider().padding(.leading, 52)
                        adminRow("person.2", "Users", count: 0, route: .adminUsers)
                        Divider().padding(.leading, 52)
                        adminRow("calendar.badge.clock", "Bookings & inquiries", count: stats.bookingRequests, route: .adminBookings)
                        Divider().padding(.leading, 52)
                        adminRow("flag", "Reports & complaints", count: stats.openReports, route: .adminReports)
                        Divider().padding(.leading, 52)
                        adminRow("creditcard", "Transactions", count: 0, route: .adminTransactions)
                    }
                    .card(padding: 4)
                    .padding(.horizontal, 16)
                }

                recentActivity

                Button("Reset demo data") { showReset = true }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAccount) { AccountSheet() }
        .confirmationDialog("Reset all data to the starter set?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { store.resetDemoData() }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Admin Panel").font(.subheadline.weight(.medium)).foregroundStyle(Theme.muted)
                Text("Platform overview").font(.largeTitle.bold()).foregroundStyle(Theme.ink)
                Text("Platform fee revenue: \(Money.naira(store.adminStats.revenue))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { showAccount = true } label: {
                AvatarView(account: store.currentUser, size: 50)
                    .overlay(alignment: .topTrailing) {
                        if store.unreadNotificationCount > 0 {
                            Circle().fill(Theme.accent).frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Theme.canvas, lineWidth: 2))
                        }
                    }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Account")
        }
        .padding(.horizontal, 16)
    }

    private func statTile(_ value: String, _ label: String, _ symbol: String, _ route: Route) -> some View {
        Button {
            router.push(route)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(Theme.primary)
                    .frame(width: 36, height: 36)
                    .background(Theme.primarySoft, in: .circle)
                Text(value).font(.title.bold()).monospacedDigit().foregroundStyle(Theme.ink)
                Text(label).font(.subheadline).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var activityCard: some View {
        let data: [(String, Int)] = [
            ("Hotels", store.data.bookings.filter { $0.kind == .hotelReservation }.count),
            ("Shortlets", store.data.bookings.filter { $0.kind == .shortletBooking }.count),
            ("Rentals", store.data.bookings.filter { $0.category == .rent }.count),
            ("Sales", store.data.bookings.filter { $0.category == .sale }.count),
            ("Listings", store.data.listings.count)
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("Platform activity").font(.headline).foregroundStyle(Theme.ink)
            Chart(data, id: \.0) { item in
                BarMark(x: .value("Count", item.1), y: .value("Type", item.0))
                    .foregroundStyle(item.0 == "Listings" ? Theme.accent : Theme.primary)
                    .cornerRadius(5)
                    .annotation(position: .trailing) {
                        Text("\(item.1)").font(.caption.bold()).foregroundStyle(Theme.ink)
                    }
            }
            .chartXAxis(.hidden)
            .frame(height: 190)
        }
        .card()
        .padding(.horizontal, 16)
    }

    private func adminRow(_ symbol: String, _ title: String, count: Int, route: Route) -> some View {
        ProfileRow(symbol: symbol, title: title, badge: count) { router.push(route) }
    }

    private var recentActivity: some View {
        let notes = Array(store.myNotifications.prefix(4))
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent activity", actionTitle: "All") { router.push(.notifications) }
            VStack(alignment: .leading, spacing: 12) {
                if notes.isEmpty {
                    Text("No recent activity.").font(.subheadline).foregroundStyle(Theme.muted)
                }
                ForEach(notes) { note in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: note.kind.symbol)
                            .font(.footnote)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Theme.accentSoft, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Text(note.body).font(.footnote).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(note.createdAt.relativeText).font(.caption2).foregroundStyle(Theme.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .padding(.horizontal, 16)
        }
    }
}
