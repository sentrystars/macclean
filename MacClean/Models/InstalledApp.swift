import Foundation

/// 已安装应用的关联文件。
struct AssociatedFile: Identifiable, Sendable, Hashable {
    let url: URL
    let kind: String
    let sizeBytes: Int64

    var id: String { url.path }

    var displayName: String { url.lastPathComponent }
}

/// 扫描到的已安装应用。
struct InstalledApp: Identifiable, Sendable {
    let bundleURL: URL
    let name: String
    let bundleIdentifier: String?
    let version: String?
    let sizeBytes: Int64
    let lastUsed: Date?
    var associatedFiles: [AssociatedFile]

    var id: String { bundleURL.path }

    /// 系统自带应用（com.apple.*）不参与卸载。
    var isSystemApp: Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifier.hasPrefix("com.apple.")
    }

    var associatedBytes: Int64 { associatedFiles.reduce(0) { $0 + $1.sizeBytes } }
    var totalBytes: Int64 { sizeBytes + associatedBytes }

    var lastUsedFormatted: String? {
        guard let lastUsed else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUsed, relativeTo: Date())
    }
}

/// 卸载结果。
struct UninstallResult: Sendable {
    let appName: String
    let movedToTrash: [String]
    let failures: [CleanupFailure]
    let freedBytes: Int64

    var succeeded: Bool { failures.isEmpty }
}
