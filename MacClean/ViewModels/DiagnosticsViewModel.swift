import Foundation

@MainActor
@Observable
final class DiagnosticsViewModel {
    var storageInfo: StorageInfo?
    var largeDirectories: [ScanItem] = []
    var appBreakdown: [ScanItem] = []
    var timeMachineSnapshots: [TimeMachineSnapshot] = []
    var isScanning = false
    var error: String?

    private let diagnosticService = DiagnosticService()

    func runFullDiagnostics() async {
        isScanning = true
        error = nil

        do {
            storageInfo = try await diagnosticService.getStorageInfo()
        } catch {
            self.error = error.localizedDescription
        }

        // Large directories
        largeDirectories = []
        for await item in await diagnosticService.getLargeDirectories(under: URL.homeDirectory.appendingPathComponent("Library"), count: 15) {
            largeDirectories.append(item)
        }

        // App breakdown
        appBreakdown = []
        for await item in await diagnosticService.getAppStorageBreakdown() {
            appBreakdown.append(item)
        }

        // Time Machine
        timeMachineSnapshots = (try? await diagnosticService.getTimeMachineSnapshots()) ?? []

        isScanning = false
    }
}
