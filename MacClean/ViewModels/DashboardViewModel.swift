import Foundation

@MainActor
@Observable
final class DashboardViewModel {
    var storageInfo: StorageInfo?
    var isScanning = false
    var error: String?

    private let diagnosticService = DiagnosticService()

    func refreshStorageInfo() async {
        isScanning = true
        error = nil
        do {
            storageInfo = try await diagnosticService.getStorageInfo()
        } catch {
            self.error = error.localizedDescription
        }
        isScanning = false
    }
}
