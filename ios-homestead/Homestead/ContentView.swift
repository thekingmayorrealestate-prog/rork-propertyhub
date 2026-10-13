import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeView().appRoutes()
                }
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                NavigationStack(path: $router.searchPath) {
                    SearchView().appRoutes()
                }
            }
            Tab("Saved", systemImage: "heart", value: AppTab.saved) {
                NavigationStack(path: $router.savedPath) {
                    SavedView().appRoutes()
                }
            }
            Tab("Bookings", systemImage: "calendar", value: AppTab.bookings) {
                NavigationStack(path: $router.bookingsPath) {
                    BookingsView().appRoutes()
                }
            }
            .badge(store.isSignedIn && store.currentUser?.role == .user ? store.unreadNotificationCount : 0)
            Tab("Profile", systemImage: "person", value: AppTab.profile) {
                NavigationStack(path: $router.profilePath) {
                    ProfileRootView().appRoutes()
                }
            }
        }
        .tint(Theme.accent)
        .sheet(isPresented: $router.isAuthPresented) {
            AuthView()
        }
        .onChange(of: store.currentUserID) { _, newValue in
            if newValue == nil { router.resetPaths() }
        }
        .onChange(of: store.currentUser?.role) { _, _ in
            router.profilePath = []
        }
    }
}

extension View {
    func appRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            RouteDestination(route: route)
        }
    }
}

struct RouteDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case .listing(let id): ListingDetailView(listingID: id)
        case .category(let category):
            if category == .hotel { HotelsView() } else { CategoryListView(category: category) }
        case .booking(let id): BookingDetailView(bookingID: id)
        case .receipt(let id): ReceiptView(paymentID: id)
        case .chat(let id): ChatView(threadID: id)
        case .messages: MessagesView()
        case .notifications: NotificationsView()
        case .payments: PaymentsListView()
        case .agentListing(let id): AgentListingManageView(listingID: id)
        case .agentListings: AgentListingsView()
        case .agentRequests: AgentRequestsView()
        case .hotelRooms(let id): HotelRoomsView(listingID: id)
        case .adminHotelOwners: AdminAgentsView(role: .hotelOwner)
        case .adminListings: AdminListingsView()
        case .adminAgents: AdminAgentsView()
        case .adminUsers: AdminUsersView()
        case .adminBookings: AdminBookingsView()
        case .adminReports: AdminReportsView()
        case .adminTransactions: AdminTransactionsView()
        }
    }
}
