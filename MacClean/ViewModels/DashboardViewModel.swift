import Foundation

@MainActor
@Observable
final class DashboardViewModel {
    var storageInfo: StorageInfo?
    var isScanning = false
    var error: String?
    var lastRefreshed: Date?

    private let diagnosticService = DiagnosticService()

    func refreshStorageInfo() async {
        isScanning = true
        error = nil
        lastRefreshed = nil
        do {
            storageInfo = try await diagnosticService.getStorageInfo()
            lastRefreshed = Date()
        } catch {
            self.error = error.localizedDescription
        }
        isScanning = false
    }
}
