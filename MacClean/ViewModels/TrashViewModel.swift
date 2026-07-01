import Foundation

@MainActor
@Observable
final class TrashViewModel {
    var trashItems: [URL] = []
    var trashSize: Int64 = 0
    var isEmptying = false
    var result: CleanupResult?

    private let trashService = TrashService()

    func refresh() async {
        trashSize = await trashService.getTrashSize()
        trashItems = await trashService.getTrashContents()
    }

    func emptyTrash() async {
        isEmptying = true
        result = try? await trashService.emptyTrash()
        isEmptying = false
        await refresh()
    }

    func secureEmptyTrash() async {
        isEmptying = true
        result = try? await trashService.secureEmptyTrash()
        isEmptying = false
        await refresh()
    }
}
