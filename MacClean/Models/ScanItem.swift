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
    /// 单项风险等级；默认继承分类，可被扫描器覆盖（如 Xcode Archives）。
    var riskLevel: RiskLevel
    /// 是否可由通用删除流程处理。信息类条目（如 sleepimage）为 false。
    var isRemovable: Bool
    /// 不可删除时的说明（用于 UI 提示）。
    var notRemovableReason: String?
    /// 是否需要管理员权限。
    var requiresPrivilege: Bool

    init(
        id: UUID = UUID(),
        url: URL,
        category: CleanupCategory,
        subcategory: String? = nil,
        sizeBytes: Int64,
        isDirectory: Bool,
        lastModified: Date? = nil,
        isSelected: Bool? = nil,
        riskLevel: RiskLevel? = nil,
        isRemovable: Bool = true,
        notRemovableReason: String? = nil,
        requiresPrivilege: Bool = false
    ) {
        self.id = id
        self.url = url
        self.category = category
        self.subcategory = subcategory
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
        self.lastModified = lastModified
        let resolvedRisk = riskLevel ?? category.riskLevel
        self.riskLevel = resolvedRisk
        // 默认勾选由风险等级推导：只有 safe 才默认选中，避免"全选后一键误删"。
        self.isSelected = isSelected ?? (resolvedRisk == .safe)
        self.isRemovable = isRemovable
        self.notRemovableReason = notRemovableReason
        self.requiresPrivilege = requiresPrivilege
    }

    var displayName: String {
        subcategory ?? url.lastPathComponent
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
