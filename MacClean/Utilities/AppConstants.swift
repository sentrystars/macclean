import Foundation

/// 应用缓存锚点：扫描时只在其下寻找缓存叶子，避免误删配置目录。
struct AppCacheAnchor: Sendable, Equatable {
    let name: String
    let path: String
}

enum AppConstants {
    static let appName = "MacClean"

    // MARK: - 用户级路径
    static let userCachePath = "Library/Caches"
    static let userLogsPath = "Library/Logs"
    static let containersPath = "Library/Containers"
    static let trashPath = ".Trash"

    static let claudeVMBundle = "Library/Application Support/Claude-3p/vm_bundles/claudevm.bundle"

    /// 只在锚点下清理缓存叶子目录（Cache/GPUCache/Code Cache/...）。
    static let appCacheAnchors: [AppCacheAnchor] = [
        AppCacheAnchor(name: "Claude", path: "Library/Application Support/Claude-3p"),
        AppCacheAnchor(name: "OpenAI Atlas", path: "Library/Application Support/com.openai.atlas"),
        AppCacheAnchor(name: "Codex", path: "Library/Application Support/Codex"),
        AppCacheAnchor(name: "Windsurf", path: "Library/Application Support/Windsurf"),
        AppCacheAnchor(name: "VS Code", path: "Library/Application Support/Code"),
        AppCacheAnchor(name: "Bilibili", path: "Library/Application Support/bilibili"),
        AppCacheAnchor(name: "Brave", path: "Library/Application Support/BraveSoftware/Brave-Browser"),
        AppCacheAnchor(name: "Chrome", path: "Library/Application Support/Google/Chrome"),
    ]

    // MARK: - Xcode
    static let xcodeDerivedData = "Library/Developer/Xcode/DerivedData"
    static let xcodeDeviceSupport = "Library/Developer/Xcode/iOS DeviceSupport"
    static let xcodeArchives = "Library/Developer/Xcode/Archives"
    static let coreSimulator = "Library/Developer/CoreSimulator"

    // MARK: - 备份
    static let iOSBackupPath = "Library/Application Support/MobileSync/Backup"

    /// 大文件搜索根目录（相对用户主目录）。
    static let largeFileSearchPaths = [
        "Downloads", "Documents", "Desktop", "Movies", "Music", "Pictures", "Public",
    ]
}