import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {

    var storageInfo: StorageInfo? { StorageStore.shared.storageInfo }
    var isScanning: Bool { StorageStore.shared.isRefreshing }
    var error: String? { StorageStore.shared.error }
    var lastRefreshed: Date? { StorageStore.shared.lastRefreshed }

    func refreshStorageInfo(force: Bool = false) async {
        await StorageStore.shared.refresh(force: force)
    }
}
