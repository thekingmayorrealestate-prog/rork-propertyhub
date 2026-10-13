import Foundation

nonisolated enum RoomKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case single, double, twin, deluxe, suite, family

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: "Single"
        case .double: "Double"
        case .twin: "Twin"
        case .deluxe: "Deluxe"
        case .suite: "Suite"
        case .family: "Family"
        }
    }

    var symbol: String {
        switch self {
        case .single: "bed.double"
        case .double, .deluxe: "bed.double.fill"
        case .twin: "square.split.2x1"
        case .suite: "sparkles"
        case .family: "figure.2.and.child.holdinghands"
        }
    }

    var defaultCapacity: Int {
        switch self {
        case .single: 1
        case .double, .twin, .deluxe: 2
        case .suite: 3
        case .family: 5
        }
    }
}

/// A bookable room category inside a hotel, with its own nightly rate and inventory.
nonisolated struct RoomType: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var kind: RoomKind
    var pricePerNight: Int
    var capacity: Int
    var totalRooms: Int
    var bedInfo: String
    var sizeSqm: Int
    var amenities: [Facility]
    var imageName: String?
    var isOpen: Bool

    static func blank() -> RoomType {
        RoomType(id: UUID(), name: "", kind: .double, pricePerNight: 0, capacity: 2, totalRooms: 5, bedInfo: "1 king bed", sizeSqm: 28, amenities: [.wifi, .ac], imageName: nil, isOpen: true)
    }

    /// Price breakdown for this room: nightly rate × nights × rooms, plus a 5% service fee.
    func quote(nights: Int, rooms: Int) -> (subtotal: Int, fee: Int, total: Int) {
        let subtotal = pricePerNight * max(nights, 1) * max(rooms, 1)
        let fee = Int((Double(subtotal) * 0.05).rounded())
        return (subtotal, fee, subtotal + fee)
    }
}

nonisolated enum CancellationPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case flexible, moderate, strict

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flexible: "Flexible"
        case .moderate: "Moderate"
        case .strict: "Strict"
        }
    }

    var summary: String {
        switch self {
        case .flexible: "Free cancellation up to 24 hours before check-in. 50% refund after that."
        case .moderate: "Free cancellation up to 5 days before check-in. 50% refund within 5 days."
        case .strict: "50% refund up to 7 days before check-in. Non-refundable within 7 days."
        }
    }

    /// Share of the payment returned when a guest cancels `hoursBefore` check-in.
    func refundFraction(hoursBefore: Double) -> Double {
        switch self {
        case .flexible: hoursBefore >= 24 ? 1 : (hoursBefore > 0 ? 0.5 : 0)
        case .moderate: hoursBefore >= 120 ? 1 : (hoursBefore > 0 ? 0.5 : 0)
        case .strict: hoursBefore >= 168 ? 0.5 : 0
        }
    }
}

/// Hotel-specific information attached to a hotel listing.
nonisolated struct HotelDetails: Codable, Hashable, Sendable {
    var starRating: Int
    var checkInTime: String
    var checkOutTime: String
    var policy: CancellationPolicy
    var checkInRequirements: String
    var rooms: [RoomType]

    static func blank() -> HotelDetails {
        HotelDetails(starRating: 3, checkInTime: "2:00 PM", checkOutTime: "12:00 PM", policy: .moderate, checkInRequirements: "Valid government-issued ID required at check-in.", rooms: [])
    }

    var openRooms: [RoomType] { rooms.filter(\.isOpen) }
    var lowestRate: Int { openRooms.map(\.pricePerNight).min() ?? rooms.map(\.pricePerNight).min() ?? 0 }
    var maxCapacity: Int { rooms.map(\.capacity).max() ?? 0 }
    var totalRooms: Int { rooms.reduce(0) { $0 + $1.totalRooms } }
}

/// A guest review left after a stay.
nonisolated struct Review: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var listingID: UUID
    var userID: UUID
    var authorName: String
    var rating: Int
    var text: String
    var createdAt: Date
}
