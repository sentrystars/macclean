import Foundation
import Observation

/// 单次清理记录。
struct CleanupRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let freedBytes: Int64
    let removedItems: Int
    let failedItems: Int
    let categoryNames: [String]
}

/// 清理历史：保留最近若干条记录，供仪表盘展示。
@MainActor
@Observable
final class CleanupHistory {

    static let shared = CleanupHistory()

    private(set) var records: [CleanupRecord] = []

    private let defaults = UserDefaults.standard
    private let storageKey = "MacClean.cleanupHistory"
    private let maximumRecords = 20

    private init() {
        load()
    }

    var lastCleanupDate: Date? { records.first?.date }
    var lastFreedBytes: Int64 { records.first?.freedBytes ?? 0 }
    var totalFreedBytes: Int64 { records.reduce(0) { $0 + $1.freedBytes } }

    func record(summary: CleanupSummary) {
        guard summary.freedBytes > 0 || summary.removedItems > 0 else { return }
        let record = CleanupRecord(
            id: UUID(),
            date: Date(),
            freedBytes: summary.freedBytes,
            removedItems: summary.removedItems,
            failedItems: summary.failures.count,
            categoryNames: summary.results.map { $0.category.displayName }
        )
        records.insert(record, at: 0)
        if records.count > maximumRecords {
            records = Array(records.prefix(maximumRecords))
        }
        save()
        AppLog.cleanup.notice("history recorded freed=\(summary.freedBytes) items=\(summary.removedItems)")
    }

    func reset() {
        records = []
        defaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CleanupRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
