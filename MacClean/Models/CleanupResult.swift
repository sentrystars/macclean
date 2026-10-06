import Foundation

struct CleanupResult: Identifiable, Codable, Sendable {
    let id: UUID
    let category: CleanupCategory
    let bytesFreed: Int64
    let itemsRemoved: Int
    let errors: [String]
    let duration: TimeInterval

    init(
        id: UUID = UUID(),
        category: CleanupCategory,
        bytesFreed: Int64,
        itemsRemoved: Int,
        errors: [String] = [],
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.category = category
        self.bytesFreed = bytesFreed
        self.itemsRemoved = itemsRemoved
        self.errors = errors
        self.duration = duration
    }

    var bytesFreedFormatted: String {
        FileSizeFormatter.string(from: bytesFreed)
    }
}

/// 单个条目的失败/拒绝记录。旧实现把失败计数成成功且不返回错误，这里显式建模。
struct CleanupFailure: Identifiable, Sendable, Equatable {
    let id: UUID
    let path: String
    let reason: String
    /// true 表示被安全策略主动拒绝，false 表示执行失败。
    let isPolicyDenied: Bool

    init(id: UUID = UUID(), path: String, reason: String, isPolicyDenied: Bool = false) {
        self.id = id
        self.path = path
        self.reason = reason
        self.isPolicyDenied = isPolicyDenied
    }

    var displayName: String {
        (path as NSString).lastPathComponent
    }
}

/// 一次清理的完整结果。
struct CleanupSummary: Sendable {
    let results: [CleanupResult]
    let failures: [CleanupFailure]
    let freedBytes: Int64
    let removedItems: Int
    let duration: TimeInterval

    static let empty = CleanupSummary(results: [], failures: [], freedBytes: 0, removedItems: 0, duration: 0)

    var succeeded: Bool { failures.isEmpty }
    var deniedFailures: [CleanupFailure] { failures.filter(\.isPolicyDenied) }
    var executionFailures: [CleanupFailure] { failures.filter { !$0.isPolicyDenied } }
}

/// 清理过程的流式事件，避免 VM 层再从进度反推结果（旧实现因此出现分类错误与重复计数）。
enum CleanupEvent: Sendable {
    case progress(CleanProgress)
    case finished(CleanupSummary)
}
