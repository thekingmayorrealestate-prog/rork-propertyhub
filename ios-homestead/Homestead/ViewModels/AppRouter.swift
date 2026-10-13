import SwiftUI
import Observation

enum AppTab: Hashable {
    case home, search, saved, bookings, profile
}

enum Route: Hashable {
    case listing(UUID)
    case category(ListingCategory)
    case booking(UUID)
    case receipt(UUID)
    case chat(UUID)
    case messages
    case notifications
    case payments
    case agentListing(UUID)
    case agentListings
    case agentRequests
    case hotelRooms(UUID)
    case adminListings
    case adminAgents
    case adminHotelOwners
    case adminUsers
    case adminBookings
    case adminReports
    case adminTransactions
}

enum SortOption: String, CaseIterable, Identifiable {
    case recommended, newest, priceLow, priceHigh, rating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: "Recommended"
        case .newest: "Newest"
        case .priceLow: "Price: low to high"
        case .priceHigh: "Price: high to low"
        case .rating: "Top rated"
        }
    }
}

struct SearchFilters: Equatable {
    var query: String = ""
    var category: ListingCategory?
    var city: String?
    var types: Set<PropertyType> = []
    var minBedrooms: Int = 0
    var minPrice: Int?
    var maxPrice: Int?
    var facilities: Set<Facility> = []
    var verifiedOnly: Bool = false
    var sort: SortOption = .recommended
    var checkIn: Date?
    var checkOut: Date?
    var guests: Int = 1
    var rooms: Int = 1
    var roomKind: RoomKind?

    static func defaultStay() -> SearchFilters {
        var f = SearchFilters()
        f.category = .hotel
        let today = Calendar.current.startOfDay(for: Date())
        f.checkIn = Calendar.current.date(byAdding: .day, value: 1, to: today)
        f.checkOut = Calendar.current.date(byAdding: .day, value: 3, to: today)
        f.guests = 2
        return f
    }

    var hasDates: Bool {
        guard let checkIn, let checkOut else { return false }
        return checkOut > checkIn
    }

    var nights: Int {
        guard let checkIn, let checkOut else { return 0 }
        let cal = Calendar.current
        return max(cal.dateComponents([.day], from: cal.startOfDay(for: checkIn), to: cal.startOfDay(for: checkOut)).day ?? 0, 0)
    }

    var activeCount: Int {
        var n = 0
        if hasDates { n += 1 }
        if guests > 1 || rooms > 1 { n += 1 }
        if roomKind != nil { n += 1 }
        if city != nil { n += 1 }
        if !types.isEmpty { n += 1 }
        if minBedrooms > 0 { n += 1 }
        if minPrice != nil || maxPrice != nil { n += 1 }
        if !facilities.isEmpty { n += 1 }
        if verifiedOnly { n += 1 }
        return n
    }
}

/// Tab selection, per-tab navigation paths, shared search filters and auth presentation.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath: [Route] = []
    var searchPath: [Route] = []
    var savedPath: [Route] = []
    var bookingsPath: [Route] = []
    var profilePath: [Route] = []

    var isAuthPresented = false
    var isSearchFocused = false
    var filters = SearchFilters()
    var compareIDs: [UUID] = []
    /// Dates, guests and rooms for hotel browsing, shared between the hotel search and hotel detail screens.
    var hotelStay = SearchFilters.defaultStay()

    /// Adds or removes a hotel from the comparison tray (max 3).
    func toggleCompare(_ id: UUID) {
        if let idx = compareIDs.firstIndex(of: id) {
            compareIDs.remove(at: idx)
        } else {
            if compareIDs.count >= 3 { compareIDs.removeFirst() }
            compareIDs.append(id)
        }
    }

    func push(_ route: Route) {
        switch selectedTab {
        case .home: homePath.append(route)
        case .search: searchPath.append(route)
        case .saved: savedPath.append(route)
        case .bookings: bookingsPath.append(route)
        case .profile: profilePath.append(route)
        }
    }

    func presentAuth() {
        isAuthPresented = true
    }

    func openSearch(category: ListingCategory? = nil, focus: Bool = false) {
        if let category { filters.category = category }
        searchPath = []
        selectedTab = .search
        if focus {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                self.isSearchFocused = true
            }
        }
    }

    func resetPaths() {
        homePath = []
        searchPath = []
        savedPath = []
        bookingsPath = []
        profilePath = []
    }
}
