import Foundation

nonisolated enum ListingCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case rent
    case shortlet
    case hotel
    case sale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rent: "Rent"
        case .shortlet: "Shortlet"
        case .hotel: "Hotel"
        case .sale: "Buy"
        }
    }

    /// Action title used on the home screen service tiles.
    var serviceTitle: String {
        switch self {
        case .rent: "Rent an Apartment"
        case .shortlet: "Book a Shortlet"
        case .hotel: "Book a Hotel"
        case .sale: "Buy a Property"
        }
    }

    var pluralTitle: String {
        switch self {
        case .rent: "Homes for Rent"
        case .shortlet: "Shortlet Stays"
        case .hotel: "Hotels & Resorts"
        case .sale: "Properties for Sale"
        }
    }

    var symbol: String {
        switch self {
        case .rent: "key.fill"
        case .shortlet: "suitcase.rolling.fill"
        case .hotel: "bed.double.fill"
        case .sale: "house.fill"
        }
    }

    var heroImage: String {
        switch self {
        case .rent: "highrise_apartment_living_room"
        case .shortlet: "beach_house_infinity_pool"
        case .hotel: "luxury_hotel_exterior_dusk"
        case .sale: "luxury_duplex_terrace"
        }
    }

    /// Categories that property agents, landlords and sellers can list.
    static let propertyCategories: [ListingCategory] = [.rent, .shortlet, .sale]
}

nonisolated enum PropertyType: String, Codable, CaseIterable, Identifiable, Sendable {
    case apartment, house, duplex, studio, villa, land, commercial, hotel, guesthouse, resort

    var id: String { rawValue }
    var title: String { self == .guesthouse ? "Guesthouse" : rawValue.capitalized }

    static let hotelTypes: [PropertyType] = [.hotel, .guesthouse, .resort]
    static let propertyTypes: [PropertyType] = [.apartment, .house, .duplex, .studio, .villa, .land, .commercial]

    static func types(for category: ListingCategory?) -> [PropertyType] {
        switch category {
        case .hotel: hotelTypes
        case .none: allCases
        default: propertyTypes
        }
    }
}

nonisolated enum PriceUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case night, month, year, total

    var id: String { rawValue }

    var suffix: String {
        switch self {
        case .night: "/ night"
        case .month: "/ month"
        case .year: "/ year"
        case .total: ""
        }
    }

    var title: String {
        switch self {
        case .night: "Per night"
        case .month: "Per month"
        case .year: "Per year"
        case .total: "Asking price"
        }
    }
}

nonisolated enum ListingStatus: String, Codable, CaseIterable, Sendable {
    case pending, live, rejected, unavailable

    var title: String {
        switch self {
        case .pending: "Pending approval"
        case .live: "Live"
        case .rejected: "Rejected"
        case .unavailable: "Unavailable"
        }
    }
}

nonisolated enum Facility: String, Codable, CaseIterable, Identifiable, Sendable {
    case wifi, pool, power, parking, security, gym, ac, kitchen, furnished, water, bq, garden
    case restaurant, breakfast, spa, roomService, airportShuttle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .pool: "Pool"
        case .power: "24h Power"
        case .parking: "Parking"
        case .security: "Security"
        case .gym: "Gym"
        case .ac: "Air conditioning"
        case .kitchen: "Fitted kitchen"
        case .furnished: "Furnished"
        case .water: "Borehole water"
        case .bq: "Boys' quarters"
        case .garden: "Garden"
        case .restaurant: "Restaurant"
        case .breakfast: "Breakfast included"
        case .spa: "Spa"
        case .roomService: "Room service"
        case .airportShuttle: "Airport shuttle"
        }
    }

    var symbol: String {
        switch self {
        case .wifi: "wifi"
        case .pool: "figure.pool.swim"
        case .power: "bolt.fill"
        case .parking: "car.fill"
        case .security: "shield.lefthalf.filled"
        case .gym: "dumbbell.fill"
        case .ac: "snowflake"
        case .kitchen: "fork.knife"
        case .furnished: "sofa.fill"
        case .water: "drop.fill"
        case .bq: "house.lodge.fill"
        case .garden: "leaf.fill"
        case .restaurant: "fork.knife.circle.fill"
        case .breakfast: "cup.and.saucer.fill"
        case .spa: "sparkles"
        case .roomService: "bell.fill"
        case .airportShuttle: "airplane"
        }
    }

    static let propertyFacilities: [Facility] = [.wifi, .pool, .power, .parking, .security, .gym, .ac, .kitchen, .furnished, .water, .bq, .garden]
    static let hotelFacilities: [Facility] = [.wifi, .pool, .restaurant, .breakfast, .parking, .ac, .gym, .spa, .roomService, .airportShuttle, .power, .security]

    static func options(for category: ListingCategory?) -> [Facility] {
        switch category {
        case .hotel: hotelFacilities
        case .none: allCases
        default: propertyFacilities
        }
    }
}

/// A property advertised on the marketplace for rent, shortlet, or sale.
nonisolated struct Listing: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var category: ListingCategory
    var propertyType: PropertyType
    var priceUnit: PriceUnit
    var price: Int
    var city: String
    var area: String
    var address: String
    var latitude: Double
    var longitude: Double
    var bedrooms: Int
    var bathrooms: Int
    var sleeps: Int
    var sizeSqm: Int
    var facilities: [Facility]
    var summary: String
    var terms: String
    var imageNames: [String]
    var agentID: UUID
    var status: ListingStatus
    var rejectionReason: String?
    var isFeatured: Bool
    var rating: Double
    var reviewCount: Int
    var weeklyViews: [Int]
    var createdAt: Date
    var hotel: HotelDetails? = nil

    var isHotel: Bool { category == .hotel }
    var locationLine: String { "\(area), \(city)" }

    func room(_ id: UUID?) -> RoomType? {
        guard let id else { return nil }
        return hotel?.rooms.first { $0.id == id }
    }
    var totalViews: Int { weeklyViews.reduce(0, +) }

    var specLine: String {
        if let hotel, isHotel {
            return "\(hotel.starRating)★ \(propertyType.title) · \(hotel.rooms.count) room type\(hotel.rooms.count == 1 ? "" : "s") · \(locationLine)"
        }
        if propertyType == .land {
            return "\(sizeSqm.formatted()) sqm · \(locationLine)"
        }
        return "\(bedrooms) bd · \(bathrooms) ba · \(locationLine)"
    }

    var priceText: String {
        category == .shortlet || category == .hotel ? Money.naira(price) : Money.compact(price)
    }

    /// Price breakdown for a shortlet stay, including a 5% service fee.
    func quote(nights: Int) -> (subtotal: Int, fee: Int, total: Int) {
        let subtotal = price * max(nights, 1)
        let fee = Int((Double(subtotal) * 0.05).rounded())
        return (subtotal, fee, subtotal + fee)
    }

    static func blank(agentID: UUID) -> Listing {
        Listing(
            id: UUID(), title: "", category: .rent, propertyType: .apartment, priceUnit: .year, price: 0,
            city: "Lagos", area: "", address: "", latitude: 6.455, longitude: 3.42,
            bedrooms: 2, bathrooms: 2, sleeps: 4, sizeSqm: 120, facilities: [], summary: "", terms: "",
            imageNames: [], agentID: agentID, status: .pending, rejectionReason: nil, isFeatured: false,
            rating: 0, reviewCount: 0, weeklyViews: Array(repeating: 0, count: 7), createdAt: Date()
        )
    }
}
