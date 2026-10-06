import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class LoginItemsViewModel {

    var items: [LoginItem] = []
    var isScanning = false
    var busyItemID: String?
    var error: String?
    var message: String?

    private let manager = LoginItemManager()

    var grouped: [(scope: LoginItemScope, items: [LoginItem])] {
        LoginItemScope.allCases.compactMap { scope in
            let filtered = items.filter { $0.scope == scope }
            return filtered.isEmpty ? nil : (scope, filtered)
        }
    }

    func scan() async {
        isScanning = true
        error = nil
        items = await manager.listItems()
        isScanning = false
    }

    func setEnabled(_ item: LoginItem, enabled: Bool) async {
        busyItemID = item.id
        error = nil
        message = nil
        switch await manager.setEnabled(item, enabled: enabled) {
        case .success:
            message = enabled ? "已启用「\(item.label)」" : "已停用「\(item.label)」"
        case .failure(let failure):
            error = failure.localizedDescription
        }
        busyItemID = nil
        await scan()
    }

    func remove(_ item: LoginItem) async {
        busyItemID = item.id
        error = nil
        message = nil
        switch await manager.remove(item) {
        case .success:
            message = "已把「\(item.label)」移入废纸篓"
            items.removeAll { $0.id == item.id }
        case .failure(let failure):
            error = failure.localizedDescription
        }
        busyItemID = nil
    }

    func reveal(_ item: LoginItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.plistURL])
    }
}
