import Foundation

nonisolated enum UserRole: String, Codable, CaseIterable, Sendable {
    case user
    case agent
    case hotelOwner
    case admin

    var label: String {
        switch self {
        case .user: "Customer"
        case .agent: "Agent / Landlord / Seller"
        case .hotelOwner: "Hotel owner / Manager"
        case .admin: "Administrator"
        }
    }

    var isProvider: Bool { self == .agent || self == .hotelOwner }
}

/// A registered person on the platform: home seeker, agent/landlord, or administrator.
nonisolated struct Account: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var email: String
    var phone: String
    var passwordHash: String
    var salt: String
    var role: UserRole
    var agencyName: String?
    var bio: String
    var avatarName: String?
    var isVerified: Bool
    var isSuspended: Bool
    var favoriteIDs: [UUID]
    var createdAt: Date

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var shortName: String {
        let parts = name.split(separator: " ")
        guard parts.count > 1, let last = parts.last?.first else { return name }
        return "\(parts[0]) \(last)."
    }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}
