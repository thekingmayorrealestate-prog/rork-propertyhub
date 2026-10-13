import Foundation
import CryptoKit

/// Reads and writes the app's JSON database in Application Support.
nonisolated enum PersistenceService {
    static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "homestead-data.json")
    }

    static func load() -> AppData? {
        guard let raw = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(AppData.self, from: raw)
        } catch {
            print("Persistence: could not decode saved data, reseeding.")
            return nil
        }
    }

    static func save(_ data: AppData) {
        do {
            try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let raw = try encoder.encode(data)
            try raw.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("Persistence: save failed – \(error.localizedDescription)")
        }
    }
}

/// Salted SHA-256 password hashing so plain-text passwords are never stored.
nonisolated enum PasswordHasher {
    static func makeSalt() -> String { UUID().uuidString }

    static func hash(_ password: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
