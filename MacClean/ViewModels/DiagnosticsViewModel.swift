import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DiagnosticsViewModel {

    var largeDirectories: [ScanItem] = []
    var appBreakdown: [ScanItem] = []
    var largeFiles: [ScanItem] = []
    var snapshots: [TimeMachineSnapshot] = []
    var isScanning = false
    var isDeletingSnapshots = false
    var error: String?
    var maintenanceResult: MaintenanceResult?
    var hasFullDiskAccess = true
    var volumes: [VolumeInfo] = []
    var selectedVolumeID: String?
    var scopeDescription = "用户主目录 · Library"

    private let diagnostics = DiagnosticService()
    private let maintenanceService = MaintenanceService()
    private let cleanupService = CleanupService()
    private let scanService = ScanService()

    var storageInfo: StorageInfo? { StorageStore.shared.storageInfo }
    var lastRefreshed: Date? { StorageStore.shared.lastRefreshed }

    func runFullDiagnostics() async {
        isScanning = true
        error = nil
        hasFullDiskAccess = await Task.detached(priority: .utility) { [maintenanceService] in
            maintenanceService.hasFullDiskAccess()
        }.value

        await StorageStore.shared.refresh(force: true)

        volumes = diagnostics.getVolumes()
        if let selectedVolumeID, !volumes.contains(where: { $0.id == selectedVolumeID }) {
            self.selectedVolumeID = nil
        }
        await scanLargeDirectories()

        appBreakdown = []
        for await item in diagnostics.getAppStorageBreakdown() {
            appBreakdown.append(item)
        }

        largeFiles = []
        let minimum = CleanupOptions.current.largeFileThresholdBytes
        for await item in diagnostics.getLargeFiles(minimumSize: minimum, limit: 100) {
            largeFiles.append(item)
        }

        snapshots = await diagnostics.getTimeMachineSnapshots()
        isScanning = false
    }

    /// 按当前选择的范围（卷或用户主目录）扫描最大的目录。
    func scanLargeDirectories() async {
        largeDirectories = []
        let scope = volumes.first { $0.id == selectedVolumeID }
        let path = scope?.url ?? URL.homeDirectory.appendingPathComponent("Library")
        scopeDescription = scope.map { "\($0.name)（\($0.url.path)）" } ?? "用户主目录 · Library"
        for await item in diagnostics.getLargeDirectories(under: path, count: 15) {
            largeDirectories.append(item)
        }
    }

    func selectVolume(_ id: String?) async {
        selectedVolumeID = id
        await scanLargeDirectories()
    }

    func deleteTimeMachineSnapshots() async {
        isDeletingSnapshots = true
        maintenanceResult = await maintenanceService.perform(.thinTimeMachineSnapshots, options: .current)
        snapshots = await diagnostics.getTimeMachineSnapshots()
        isDeletingSnapshots = false
    }

    func moveToTrash(_ item: ScanItem) async {
        // 大文件位于下载/文档等用户目录，必须使用「用户显式选择文件」策略
        let decision = CleanupPolicy.evaluateUserSelectedFile(item.url)
        guard decision.isAllowed else {
            error = decision.reason ?? "安全策略拒绝"
            return
        }
        do {
            try FileManager.default.moveToTrash(item.url)
            largeFiles.removeAll { $0.id == item.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reveal(_ item: ScanItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}