import Foundation

nonisolated struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var senderID: UUID
    var text: String
    var sentAt: Date
}

/// A conversation between a user and the agent/landlord of a listing.
nonisolated struct ChatThread: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var listingID: UUID
    var userID: UUID
    var agentID: UUID
    var messages: [ChatMessage]
    var lastReadByUser: Date
    var lastReadByAgent: Date

    var lastActivity: Date { messages.last?.sentAt ?? lastReadByUser }
}

nonisolated enum NotificationKind: String, Codable, Sendable {
    case booking, inquiry, listing, payment, message, system

    var symbol: String {
        switch self {
        case .booking: "calendar"
        case .inquiry: "questionmark.bubble.fill"
        case .listing: "house.fill"
        case .payment: "creditcard.fill"
        case .message: "bubble.left.and.bubble.right.fill"
        case .system: "bell.fill"
        }
    }
}

nonisolated struct AppNotification: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var kind: NotificationKind
    var title: String
    var body: String
    var createdAt: Date
    var isRead: Bool
}

nonisolated struct ListingReport: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var listingID: UUID
    var reporterID: UUID
    var reason: String
    var details: String
    var createdAt: Date
    var isResolved: Bool
}

/// Everything the app persists, stored as a single JSON document.
nonisolated struct AppData: Codable, Sendable {
    var version: Int
    var accounts: [Account]
    var listings: [Listing]
    var bookings: [Booking]
    var payments: [Payment]
    var threads: [ChatThread]
    var notifications: [AppNotification]
    var reports: [ListingReport]
    var reviews: [Review] = []
}
