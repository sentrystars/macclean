import Foundation

struct DuplicateFile: Identifiable, Sendable, Hashable {
    let url: URL
    let sizeBytes: Int64
    let modified: Date?

    var id: String { url.path }
    var displayName: String { url.lastPathComponent }

    var modifiedFormatted: String? {
        guard let modified else { return nil }
        return modified.formatted(date: .abbreviated, time: .shortened)
    }
}

struct DuplicateGroup: Identifiable, Sendable {
    let id: String
    let sizeBytes: Int64
    let files: [DuplicateFile]

    var wastedBytes: Int64 { sizeBytes * Int64(max(0, files.count - 1)) }
    var count: Int { files.count }

    /// 默认保留最早修改的那一份，其余为可清理项。
    var keepCandidate: DuplicateFile? {
        files.min { ($0.modified ?? .distantFuture) < ($1.modified ?? .distantFuture) }
    }
}
