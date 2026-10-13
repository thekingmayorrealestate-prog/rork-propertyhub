import Foundation

nonisolated enum PaymentMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case card, transfer, ussd

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: "Card"
        case .transfer: "Bank transfer"
        case .ussd: "USSD"
        }
    }

    var symbol: String {
        switch self {
        case .card: "creditcard.fill"
        case .transfer: "building.columns.fill"
        case .ussd: "number.square.fill"
        }
    }
}

nonisolated enum PaymentStatus: String, Codable, Sendable {
    case paid, pending, failed, refunded

    var title: String { rawValue.capitalized }
}

/// A payment record with receipt reference for a booking or approved transaction.
nonisolated struct Payment: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var bookingID: UUID
    var userID: UUID
    var listingID: UUID
    var amount: Int
    var serviceFee: Int
    var method: PaymentMethod
    var status: PaymentStatus
    var reference: String
    var cardLast4: String?
    var createdAt: Date
    var refundedAmount: Int? = nil

    var total: Int { amount + serviceFee }
}
