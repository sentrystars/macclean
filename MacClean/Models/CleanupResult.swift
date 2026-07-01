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
