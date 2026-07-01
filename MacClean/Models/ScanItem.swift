import Foundation

struct ScanItem: Identifiable, Codable, Sendable {
    let id: UUID
    let url: URL
    let category: CleanupCategory
    let subcategory: String?
    let sizeBytes: Int64
    let isDirectory: Bool
    let lastModified: Date?
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        url: URL,
        category: CleanupCategory,
        subcategory: String? = nil,
        sizeBytes: Int64,
        isDirectory: Bool,
        lastModified: Date? = nil,
        isSelected: Bool = true
    ) {
        self.id = id
        self.url = url
        self.category = category
        self.subcategory = subcategory
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
        self.lastModified = lastModified
        self.isSelected = isSelected
    }

    var sizeFormatted: String {
        FileSizeFormatter.string(from: sizeBytes)
    }

    var lastModifiedFormatted: String? {
        guard let date = lastModified else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
