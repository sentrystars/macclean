import Foundation

enum AppConstants {
    static let appName = "MacClean"
    static let helperToolBundleID = "com.macclean.helper"

    // MARK: - User-Level Paths
    static let userCachePath = "Library/Caches"
    static let userLogsPath = "Library/Logs"
    static let crashReporterPath = "Library/Application Support/CrashReporter"
    static let containersPath = "Library/Containers"
    static let groupContainersPath = "Library/Group Containers"
    static let trashPath = ".Trash"

    // MARK: - App Support Caches
    static let claudeAppSupport = "Library/Application Support/Claude-3p"
    static let claudeVMBundle = "Library/Application Support/Claude-3p/vm_bundles/claudevm.bundle"
    static let openaiAtlas = "Library/Application Support/com.openai.atlas"
    static let openaiChat = "Library/Caches/com.openai.chat"
    static let codex = "Library/Application Support/Codex"
    static let windsurf = "Library/Application Support/Windsurf"
    static let vscode = "Library/Application Support/Code"
    static let bilibili = "Library/Application Support/bilibili"
    static let brave = "Library/Application Support/BraveSoftware/Brave-Browser"
    static let chrome = "Library/Application Support/Google/Chrome"

    // MARK: - Xcode
    static let xcodeDerivedData = "Library/Developer/Xcode/DerivedData"
    static let xcodeDeviceSupport = "Library/Developer/Xcode/iOS DeviceSupport"
    static let xcodeArchives = "Library/Developer/Xcode/Archives"
    static let coreSimulator = "Library/Developer/CoreSimulator"

    // MARK: - System Paths (require sudo)
    static let systemCaches = "/Library/Caches"
    static let systemLogs = "/Library/Logs"
    static let privateTmp = "/private/tmp"
    static let privateVarTmp = "/private/var/tmp"
    static let privateVarFolders = "/private/var/folders"
    static let systemLibraryCaches = "/System/Library/Caches"
    static let vmPath = "/private/var/vm"
    static let mobileBackups = "/.MobileBackups"

    // MARK: - iOS Backups
    static let iOSBackupPath = "Library/Application Support/MobileSync/Backup"
}
