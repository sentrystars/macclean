import Foundation

/// 已挂载的卷（含外置盘）。
struct VolumeInfo: Identifiable, Sendable, Hashable {
    let url: URL
    let name: String
    let totalBytes: Int64
    let freeBytes: Int64
    let isRemovable: Bool
    let isInternal: Bool

    var id: String { url.path }
    var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
    var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}
