import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SimulatorViewModel {

    var runtimes: [SimulatorRuntime] = []
    var devices: SimulatorDeviceSummary = .empty
    var isScanning = false
    var isBulkRunning = false
    var busyRuntimeID: String?
    var message: String?
    var error: String?
    var hasXcode = true

    private let manager = SimulatorRuntimeManager()
    private let maintenance = MaintenanceService()

    var totalBytes: Int64 { runtimes.reduce(0) { $0 + $1.sizeBytes } }
    var sortedRuntimes: [SimulatorRuntime] {
        runtimes.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    func refresh() async {
        isScanning = true
        error = nil
        hasXcode = manager.isAvailable
        guard hasXcode else {
            runtimes = []
            devices = .empty
            isScanning = false
            return
        }
        runtimes = await manager.listRuntimes()
        devices = await manager.deviceSummary()
        isScanning = false
    }

    func delete(_ runtime: SimulatorRuntime) async {
        busyRuntimeID = runtime.identifier
        error = nil
        message = nil

        switch await manager.deleteRuntime(runtime) {
        case .success(let freed):
            message = "已删除运行时「\(runtime.displayName)」"
                + (freed > 0 ? "，释放约 \(FileSizeFormatter.string(from: freed))" : "")
            await refresh()
            await StorageStore.shared.refresh(force: true)
        case .failure(let failure):
            error = failure.localizedDescription
        }
        busyRuntimeID = nil
    }

    func deleteUnusableOrOutdated() async {
        isBulkRunning = true
        error = nil
        message = nil
        switch await manager.deleteUnusableOrOutdated() {
        case .success(let freed):
            message = freed > 0
                ? "已清理不可用/过期运行时，释放约 \(FileSizeFormatter.string(from: freed))"
                : "没有不可用或过期的运行时"
            await refresh()
            await StorageStore.shared.refresh(force: true)
        case .failure(let failure):
            error = failure.localizedDescription
        }
        isBulkRunning = false
    }

    func deleteNotUsed(days: Int) async {
        isBulkRunning = true
        error = nil
        message = nil
        switch await manager.deleteNotUsedSince(days: days) {
        case .success(let freed):
            message = freed > 0
                ? "已清理 \(days) 天未使用的运行时，释放约 \(FileSizeFormatter.string(from: freed))"
                : "没有 \(days) 天以上未使用的运行时"
            await refresh()
            await StorageStore.shared.refresh(force: true)
        case .failure(let failure):
            error = failure.localizedDescription
        }
        isBulkRunning = false
    }

    func deleteUnavailableDevices() async {
        isBulkRunning = true
        error = nil
        message = nil
        let result = await maintenance.deleteUnavailableSimulators()
        if result.succeeded {
            message = result.message
            await refresh()
        } else {
            error = result.message
        }
        isBulkRunning = false
    }

    func reveal(_ runtime: SimulatorRuntime) {
        guard let path = runtime.mountPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
