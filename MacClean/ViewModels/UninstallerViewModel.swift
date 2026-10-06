import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UninstallerViewModel {

    var apps: [InstalledApp] = []
    var isScanning = false
    var searchText = ""
    var loadingAssociations: String?
    var selection: [String: Set<String>] = [:]
    var lastResult: UninstallResult?
    var error: String?
    var isUninstalling = false

    private let uninstaller = AppUninstaller()

    var filteredApps: [InstalledApp] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return apps }
        let query = searchText.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(query)
                || ($0.bundleIdentifier ?? "").lowercased().contains(query)
        }
    }

    var totalBytes: Int64 { apps.reduce(0) { $0 + $1.sizeBytes } }

    func scan() async {
        isScanning = true
        error = nil
        lastResult = nil
        apps = []
        selection = [:]
        uninstaller.resetCancellation()

        var found: [InstalledApp] = []
        for await app in uninstaller.scanInstalledApps() {
            found.append(app)
        }
        apps = found.sorted { $0.sizeBytes > $1.sizeBytes }
        isScanning = false
    }

    func cancelScan() {
        uninstaller.cancel()
        isScanning = false
    }

    func loadAssociations(for appID: String) async {
        guard let index = apps.firstIndex(where: { $0.id == appID }) else { return }
        guard apps[index].associatedFiles.isEmpty else { return }

        loadingAssociations = appID
        let app = apps[index]
        let files = await Task.detached(priority: .userInitiated) { [uninstaller] in
            uninstaller.associatedFiles(for: app)
        }.value

        if let current = apps.firstIndex(where: { $0.id == appID }) {
            apps[current].associatedFiles = files
            selection[appID] = Set(files.map { $0.url.path })
        }
        loadingAssociations = nil
    }

    func isSelected(_ appID: String, _ path: String) -> Bool {
        selection[appID]?.contains(path) ?? false
    }

    func toggleAssociated(appID: String, path: String) {
        var set = selection[appID] ?? []
        if set.contains(path) { set.remove(path) } else { set.insert(path) }
        selection[appID] = set
    }

    func selectedAssociatedURLs(for app: InstalledApp) -> [URL] {
        let selected = selection[app.id] ?? []
        return app.associatedFiles.filter { selected.contains($0.url.path) }.map(\.url)
    }

    func selectedAssociatedBytes(for app: InstalledApp) -> Int64 {
        let selected = selection[app.id] ?? []
        return app.associatedFiles.filter { selected.contains($0.url.path) }.reduce(0) { $0 + $1.sizeBytes }
    }

    func uninstall(_ app: InstalledApp) async {
        guard !app.isSystemApp else {
            error = "系统自带应用不支持卸载"
            return
        }
        isUninstalling = true
        error = nil

        await loadAssociations(for: app.id)
        let refreshed = apps.first(where: { $0.id == app.id }) ?? app
        let urls = selectedAssociatedURLs(for: refreshed)
        let result = await uninstaller.uninstall(refreshed, associatedURLs: urls)

        lastResult = result
        if !result.failures.isEmpty {
            error = result.failures.prefix(3).map { "\($0.displayName)：\($0.reason)" }.joined(separator: "；")
        }
        apps.removeAll { $0.id == app.id }
        isUninstalling = false
        await StorageStore.shared.refresh(force: true)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func icon(for path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}
