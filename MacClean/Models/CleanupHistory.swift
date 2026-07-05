import Foundation

/// Tracks cleanup history using UserDefaults for Dashboard display
@MainActor
@Observable
final class CleanupHistory {
    static let shared = CleanupHistory()

    private let defaults = UserDefaults.standard
    private let lastCleanupKey = "MacCleanLastCleanupDate"
    private let lastFreedKey = "MacCleanLastFreedBytes"
    private let totalFreedKey = "MacCleanTotalFreedBytes"

    var lastCleanupDate: Date? {
        defaults.object(forKey: lastCleanupKey) as? Date
    }

    var lastFreedBytes: Int64 {
        Int64(defaults.integer(forKey: lastFreedKey))
    }

    var totalFreedBytes: Int64 {
        Int64(defaults.integer(forKey: totalFreedKey))
    }

    func recordCleanup(freed bytes: Int64) {
        defaults.set(Date(), forKey: lastCleanupKey)
        defaults.set(Int(bytes), forKey: lastFreedKey)
        let total = defaults.integer(forKey: totalFreedKey)
        defaults.set(total + Int(bytes), forKey: totalFreedKey)
    }

    func reset() {
        defaults.removeObject(forKey: lastCleanupKey)
        defaults.removeObject(forKey: lastFreedKey)
        defaults.removeObject(forKey: totalFreedKey)
    }
}
