import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DuplicateFinderViewModel {

    var groups: [DuplicateGroup] = []
    var isScanning = false
    var minimumSizeMB = 1
    var selectedPaths: Set<String> = []
    var lastMessage: String?
    var error: String?

    private let finder = DuplicateFinder()

    var totalWasted: Int64 { groups.reduce(0) { $0 + $1.wastedBytes } }
    var totalFiles: Int { groups.reduce(0) { $0 + $1.count } }
    var selectedBytes: Int64 {
        groups.flatMap(\.files)
            .filter { selectedPaths.contains($0.url.path) }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    func scan() async {
        isScanning = true
        error = nil
        lastMessage = nil
        groups = []
        selectedPaths = []

        var found: [DuplicateGroup] = []
        let minimum = Int64(max(1, minimumSizeMB)) * 1_048_576
        for await group in finder.findDuplicates(roots: DuplicateFinder.defaultRoots, minimumSize: minimum) {
            found.append(group)
            groups = found
        }

        isScanning = false
        autoSelectExtras()
        if groups.isEmpty {
            lastMessage = "没有发现大于 \(minimumSizeMB) MB 的重复文件"
        }
    }

    func cancelScan() {
        finder.cancel()
        isScanning = false
    }

    func isSelected(_ path: String) -> Bool { selectedPaths.contains(path) }

    func toggle(_ path: String) {
        if selectedPaths.contains(path) { selectedPaths.remove(path) } else { selectedPaths.insert(path) }
    }

    /// 每组保留最早修改的一份，其余勾选为待清理。
    func autoSelectExtras() {
        var selection = Set<String>()
        for group in groups {
            guard let keep = group.keepCandidate else { continue }
            for file in group.files where file.id != keep.id {
                selection.insert(file.url.path)
            }
        }
        selectedPaths = selection
    }

    func clearSelection() { selectedPaths = [] }

    func removeSelected() async {
        let urls = groups.flatMap(\.files)
            .filter { selectedPaths.contains($0.url.path) }
            .map(\.url)
        guard !urls.isEmpty else {
            error = "没有勾选任何文件"
            return
        }

        let outcome = await finder.moveToTrash(urls)
        lastMessage = "已移入废纸篓 \(outcome.moved.count) 个文件，释放约 \(FileSizeFormatter.string(from: outcome.bytes))"
        if !outcome.failures.isEmpty {
            error = outcome.failures.prefix(3).map { "\($0.displayName)：\($0.reason)" }.joined(separator: "；")
        }

        // 重新整理结果，去掉已清理的文件
        let removed = Set(outcome.moved)
        groups = groups.compactMap { group in
            let remaining = group.files.filter { !removed.contains($0.url.path) }
            guard remaining.count > 1 else { return nil }
            return DuplicateGroup(id: group.id, sizeBytes: group.sizeBytes, files: remaining)
        }
        selectedPaths = selectedPaths.subtracting(removed)
        await StorageStore.shared.refresh(force: true)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
