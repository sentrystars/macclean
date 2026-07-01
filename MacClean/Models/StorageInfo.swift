import Foundation

struct StorageInfo: Codable, Sendable {
    let totalBytes: Int64
    let usedBytes: Int64
    let freeBytes: Int64
    var systemDataBytes: Int64?
    var appBytes: Int64?
    var documentsBytes: Int64?
    var trashBytes: Int64?
    var cacheBytes: Int64?

    var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    var freePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes)
    }
}
