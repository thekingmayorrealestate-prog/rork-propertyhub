import UIKit

/// Loads bundled listing photos and stores photos uploaded by agents on disk.
final class ImageStore {
    static let shared = ImageStore()

    private let cache = NSCache<NSString, UIImage>()
    private let localPrefix = "local:"

    private var directory: URL {
        URL.documentsDirectory.appending(path: "ListingPhotos")
    }

    func image(named name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        if let cached = cache.object(forKey: name as NSString) { return cached }
        let image: UIImage?
        if name.hasPrefix(localPrefix) {
            let file = directory.appending(path: String(name.dropFirst(localPrefix.count)))
            image = UIImage(contentsOfFile: file.path())
        } else {
            image = UIImage(named: name)
        }
        if let image { cache.setObject(image, forKey: name as NSString) }
        return image
    }

    /// Saves a resized JPEG and returns the reference name to store on a listing.
    func save(_ image: UIImage) -> String? {
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: target).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileName = "\(UUID().uuidString).jpg"
            try data.write(to: directory.appending(path: fileName), options: .atomic)
            let name = localPrefix + fileName
            cache.setObject(resized, forKey: name as NSString)
            return name
        } catch {
            print("ImageStore: failed to save photo – \(error.localizedDescription)")
            return nil
        }
    }
}

nonisolated enum Money {
    nonisolated(unsafe) private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func naira(_ value: Int) -> String {
        "₦" + (formatter.string(from: NSNumber(value: value)) ?? "\(value)")
    }

    static func compact(_ value: Int) -> String {
        let d = Double(value)
        if d >= 1_000_000_000 { return "₦" + trim(d / 1_000_000_000) + "B" }
        if d >= 1_000_000 { return "₦" + trim(d / 1_000_000) + "M" }
        return naira(value)
    }

    private static func trim(_ x: Double) -> String {
        let s = String(format: "%.1f", x)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}
