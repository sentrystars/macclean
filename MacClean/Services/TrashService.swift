import Foundation

/// 废纸篓服务：内容枚举复用 ScanService（产出条目而非目录本身），清空委托 CleanupService。
final class TrashService: Sendable {

    private let scanService = ScanService()
    private let cleanupService = CleanupService()

    func getTrashSize() -> Int64 {
        FileManager.default.trashSize()
    }

    func getTrashContents() async -> [ScanItem] {
        var items: [ScanItem] = []
        for await item in scanService.scanTrash() {
            items.append(item)
        }
        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    func emptyTrash() async -> CleanupResult {
        await cleanupService.emptyTrash()
    }
}
