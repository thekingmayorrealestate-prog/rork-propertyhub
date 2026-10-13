import Foundation

nonisolated enum RequestKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case shortletBooking, hotelReservation, rentalInquiry, purchaseInquiry, viewing

    var id: String { rawValue }

    var isStay: Bool { self == .shortletBooking || self == .hotelReservation }

    var title: String {
        switch self {
        case .shortletBooking: "Shortlet booking"
        case .hotelReservation: "Hotel reservation"
        case .rentalInquiry: "Rental inquiry"
        case .purchaseInquiry: "Purchase inquiry"
        case .viewing: "Viewing request"
        }
    }
}

nonisolated enum BookingSegment: String, CaseIterable, Identifiable, Sendable {
    case shortlets, hotels, rentals, purchases

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var category: ListingCategory {
        switch self {
        case .shortlets: .shortlet
        case .hotels: .hotel
        case .rentals: .rent
        case .purchases: .sale
        }
    }
}

nonisolated enum BookingStatus: String, Codable, CaseIterable, Sendable {
    case pending, confirmed, viewingScheduled, declined, cancelled, completed

    var title: String {
        switch self {
        case .pending: "Pending"
        case .confirmed: "Confirmed"
        case .viewingScheduled: "Viewing"
        case .declined: "Declined"
        case .cancelled: "Cancelled"
        case .completed: "Completed"
        }
    }

    var isOpen: Bool { self == .pending || self == .confirmed || self == .viewingScheduled }
}

/// A shortlet booking, rental/purchase inquiry, or viewing request made by a user.
nonisolated struct Booking: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var listingID: UUID
    var userID: UUID
    var agentID: UUID
    var category: ListingCategory
    var kind: RequestKind
    var checkIn: Date?
    var checkOut: Date?
    var guests: Int
    var viewingDate: Date?
    var message: String
    var status: BookingStatus
    var agentNote: String?
    var createdAt: Date
    var roomTypeID: UUID? = nil
    var rooms: Int = 1

    /// Short code guests show at check-in.
    var confirmationCode: String { "HS-" + id.uuidString.prefix(6).uppercased() }

    var isUpcoming: Bool {
        guard let checkOut else { return status.isOpen }
        return checkOut > Date() && status.isOpen
    }

    var nights: Int {
        guard let checkIn, let checkOut else { return 0 }
        let cal = Calendar.current
        return max(cal.dateComponents([.day], from: cal.startOfDay(for: checkIn), to: cal.startOfDay(for: checkOut)).day ?? 0, 0)
    }

    var dateSummary: String {
        if let checkIn, let checkOut {
            let start = checkIn.formatted(.dateTime.day().month(.abbreviated))
            let end = checkOut.formatted(.dateTime.day().month(.abbreviated).year())
            return "\(start) – \(end)"
        }
        if let viewingDate {
            return viewingDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        }
        return "Sent " + createdAt.formatted(.dateTime.day().month(.abbreviated))
    }

    var detailSummary: String {
        switch kind {
        case .shortletBooking: "\(nights) night\(nights == 1 ? "" : "s") · \(guests) guest\(guests == 1 ? "" : "s")"
        case .hotelReservation: "\(nights) night\(nights == 1 ? "" : "s") · \(rooms) room\(rooms == 1 ? "" : "s") · \(guests) guest\(guests == 1 ? "" : "s")"
        case .viewing: "Viewing request"
        case .rentalInquiry: "Rental inquiry"
        case .purchaseInquiry: "Purchase inquiry"
        }
    }
}
