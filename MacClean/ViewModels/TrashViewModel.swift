import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class TrashViewModel {

    var trashItems: [ScanItem] = []
    var trashSize: Int64 = 0
    var isEmptying = false
    var result: CleanupResult?
    var error: String?

    private let trashService = TrashService()

    func refresh() async {
        trashSize = trashService.getTrashSize()
        trashItems = await trashService.getTrashContents()
    }

    func emptyTrash() async {
        isEmptying = true
        error = nil
        let outcome = await trashService.emptyTrash()
        result = outcome
        if !outcome.errors.isEmpty {
            error = outcome.errors.prefix(3).joined(separator: "；")
        }
        isEmptying = false
        await refresh()
        await StorageStore.shared.refresh(force: true)
    }

    func reveal(_ item: ScanItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}
