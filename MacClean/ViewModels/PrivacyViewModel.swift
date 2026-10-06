import Foundation
import Observation

@MainActor
@Observable
final class PrivacyViewModel {

    var sizes: [String: Int64] = [:]
    var selected: Set<String> = []
    var isScanning = false
    var isCleaning = false
    var lastMessage: String?
    var error: String?

    private let cleaner = PrivacyCleaner()

    var targets: [PrivacyTarget] { PrivacyCatalog.targets }

    var groupedTargets: [(group: String, items: [PrivacyTarget])] {
        var order: [String] = []
        var map: [String: [PrivacyTarget]] = [:]
        for target in targets {
            if map[target.group] == nil { order.append(target.group) }
            map[target.group, default: []].append(target)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    var selectedBytes: Int64 { selected.reduce(0) { $0 + (sizes[$1] ?? 0) } }

    func scanSizes() async {
        isScanning = true
        error = nil
        let targets = self.targets
        let results = await Task.detached(priority: .utility) { [cleaner] in
            targets.map { cleaner.size(of: $0) }
        }.value
        var map: [String: Int64] = [:]
        for result in results { map[result.targetID] = result.bytes }
        sizes = map
        isScanning = false
    }

    func isSelected(_ id: String) -> Bool { selected.contains(id) }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    /// 返回阻止清理的应用名（若有）。
    func blockingApp() -> String? {
        for target in targets where selected.contains(target.id) {
            if let app = cleaner.runningBlocker(for: target) {
                return app
            }
        }
        return nil
    }

    func cleanSelected() async {
        guard !selected.isEmpty else {
            error = "没有勾选任何项目"
            return
        }
        if let blocker = blockingApp() {
            error = "请先退出「\(blocker)」再清理其浏览器数据，否则可能损坏配置。"
            return
        }

        isCleaning = true
        error = nil
        let targets = self.targets.filter { selected.contains($0.id) }
        let outcome = await cleaner.clean(targets)

        lastMessage = "已移入废纸篓 \(outcome.moved.count) 项，释放约 \(FileSizeFormatter.string(from: outcome.bytes))"
        if !outcome.failures.isEmpty {
            error = outcome.failures.prefix(3).map { "\($0.displayName)：\($0.reason)" }.joined(separator: "；")
        }
        selected = []
        isCleaning = false
        await scanSizes()
        await StorageStore.shared.refresh(force: true)
    }
}
