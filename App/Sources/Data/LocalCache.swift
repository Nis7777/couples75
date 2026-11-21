import Foundation

/// Codable JSON files and cached photos in the App Group container (falls back to Application Support
/// when the App Group isn't available, e.g. unsigned Simulator builds).
enum LocalCache {
    static var directory: URL {
        let fm = FileManager.default
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: Brand.appGroup)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Couples75", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static var photosDirectory: URL {
        let dir = directory.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func read<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    static func write<T: Encodable>(_ value: T, to name: String) {
        let url = directory.appendingPathComponent(name)
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    static func photoURL(_ checkInID: String) -> URL {
        photosDirectory.appendingPathComponent("\(checkInID).jpg")
    }

    static func savePhoto(_ data: Data, checkInID: String) {
        try? data.write(to: photoURL(checkInID), options: .atomic)
    }

    static func photo(_ checkInID: String) -> Data? {
        try? Data(contentsOf: photoURL(checkInID))
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: directory)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
