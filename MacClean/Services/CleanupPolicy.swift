import Foundation

/// 单个路径的清理裁决结果。
struct PolicyDecision: Sendable, Equatable {
    let isAllowed: Bool
    let requiresPrivilege: Bool
    let reason: String?

    static let allow = PolicyDecision(isAllowed: true, requiresPrivilege: false, reason: nil)

    static func allow(privileged: Bool) -> PolicyDecision {
        PolicyDecision(isAllowed: true, requiresPrivilege: privileged, reason: nil)
    }

    static func deny(_ reason: String) -> PolicyDecision {
        PolicyDecision(isAllowed: false, requiresPrivilege: false, reason: reason)
    }
}

/// 清理安全策略：所有删除动作的唯一仲裁者。
///
/// 设计原则：
/// 1. 白名单优先——只有明确列出的目录子树才可能被删除；
/// 2. 容器目录本身（如 ~/Library/Caches、~/.Trash）永不被整体删除，只清理其子项；
/// 3. 用户数据名称（Default 配置、书签、钥匙串等）一律拒绝；
/// 4. 符号链接一律拒绝，避免越过白名单；
/// 5. SIP 保护路径一律拒绝。
enum CleanupPolicy {

    // MARK: - 路径计算

    static let homePath: String = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path

    static func home(_ relative: String) -> String {
        relative.isEmpty ? homePath : homePath + "/" + relative
    }

    // MARK: - 白名单

    /// 只有这些目录的「子项」可以被删除。
    static let protectedContainers: [String] = [
        home("Library/Caches"),
        home("Library/Logs"),
        home("Library/Containers"),
        home("Library/Group Containers"),
        home("Library/Developer/Xcode/DerivedData"),
        home("Library/Developer/Xcode/iOS DeviceSupport"),
        home("Library/Developer/Xcode/Archives"),
        home("Library/Developer/CoreSimulator"),
        home("Library/Application Support/Claude-3p"),
        home("Library/Application Support/Code"),
        home("Library/Application Support/Windsurf"),
        home("Library/Application Support/Codex"),
        home("Library/Application Support/bilibili"),
        home("Library/Application Support/com.openai.atlas"),
        home("Library/Application Support/Google/Chrome"),
        home("Library/Application Support/BraveSoftware/Brave-Browser"),
        home(".Trash"),
        "/Library/Caches",
        "/Library/Logs",
        "/private/tmp",
        "/private/var/tmp",
        "/private/var/folders",
        "/System/Library/Caches",
    ]

    /// 可以整体删除的目录（完全可再生）。
    static let deletableRoots: Set<String> = [
        home("Library/Developer/Xcode/DerivedData"),
        home("Library/Developer/Xcode/iOS DeviceSupport"),
        home("Library/Application Support/MobileSync/Backup"),
    ]

    /// 应用目录中允许删除的叶子名称（小写）。
    static let allowedCacheLeafNames: Set<String> = [
        "cache", "caches", "gpucache", "code cache", "dawnwebgpucache",
        "dawngraphitecache", "cacheddata", "shadercache", "grshadercache",
        "gpu cache", "browser-data", "cachestorage", "blob_storage",
        "crashpad", "logs", "tmp", "temp", "deriveddata", "indexeddb",
    ]

    /// 需要应用锚点校验的目录（在其下只允许缓存叶子）。
    static let appAnchors: [String] = [
        home("Library/Application Support/Claude-3p"),
        home("Library/Application Support/Code"),
        home("Library/Application Support/Windsurf"),
        home("Library/Application Support/Codex"),
        home("Library/Application Support/bilibili"),
        home("Library/Application Support/com.openai.atlas"),
        home("Library/Application Support/Google/Chrome"),
        home("Library/Application Support/BraveSoftware/Brave-Browser"),
    ]

    /// 永不删除的名称（小写）。
    static let forbiddenNames: Set<String> = [
        "default", "local state", "login data", "cookies", "bookmarks",
        "web data", "history", "preferences", "secure preferences",
        "keychains", "mail", "messages", "safari", "desktop", "documents",
        "movies", "music", "pictures", "photos library.photoslibrary",
        "library", "applications", "system", "users", "volumes",
    ]

    /// 这些容器内允许出现形如 com.example.app 的目录名，后缀规则不适用。
    static let cacheLikeContainers: [String] = [
        home("Library/Caches"),
        home("Library/Logs"),
        home("Library/Containers"),
        home("Library/Group Containers"),
        "/Library/Caches",
        "/Library/Logs",
        "/private/tmp",
        "/private/var/tmp",
    ]

    /// SIP / 系统受保护前缀。
    static let protectedSystemPrefixes: [String] = [
        "/System/", "/usr/", "/bin/", "/sbin/", "/private/var/db/",
        "/Library/Keychains", "/Applications/", "/Library/LaunchDaemons",
        "/Library/LaunchAgents", "/Library/Extensions",
    ]

    // MARK: - 裁决

    static func evaluate(_ url: URL) -> PolicyDecision {
        let path = url.standardizedFileURL.path

        guard path != "/", path != homePath else {
            return .deny("磁盘根目录与用户主目录不允许删除")
        }

        for prefix in protectedSystemPrefixes where path.hasPrefix(prefix) {
            return .deny("系统受保护路径（\(prefix)）")
        }

        if isSymbolicLink(url) {
            return .deny("符号链接不参与清理")
        }

        let privileged = requiresPrivilege(for: path)

        // 废纸篓：允许清空任意内容（用户已明确丢弃），仅保留根/链接/系统校验。
        let trashPrefix = home(".Trash") + "/"
        if path.hasPrefix(trashPrefix) {
            return .allow(privileged: privileged)
        }

        let name = url.lastPathComponent.lowercased()
        if forbiddenNames.contains(name) {
            return .deny("「\(url.lastPathComponent)」属于用户数据，不能删除")
        }
        if name.hasPrefix("profile ") {
            return .deny("浏览器配置文件不能删除")
        }
        let isInsideCacheLikeContainer = cacheLikeContainers.contains { path.hasPrefix($0 + "/") }
        if !isInsideCacheLikeContainer,
           name.hasSuffix(".app") || name.hasSuffix(".photoslibrary") || name.hasSuffix(".keychain-db") {
            return .deny("应用包/资料库/钥匙串不能删除")
        }

        let underContainer = protectedContainers.contains { path.hasPrefix($0 + "/") }
        let isDeletableRoot = deletableRoots.contains(path)
        guard underContainer || isDeletableRoot else {
            return .deny("不在允许清理的目录范围内")
        }

        if let anchor = appAnchor(containing: path), !isDeletableRoot {
            guard allowedCacheLeafNames.contains(name) else {
                return .deny("应用资料目录下仅允许清理缓存子目录")
            }
            _ = anchor
        }

        // 禁止把白名单容器本身当作目标（防止 ~/Library/Caches 被整体删掉）。
        if protectedContainers.contains(path) && !isDeletableRoot {
            return .deny("容器目录本身不能删除，只能清理其内容")
        }

        return .allow(privileged: privileged)
    }

    static func isAllowed(_ url: URL) -> Bool {
        evaluate(url).isAllowed
    }

    /// 是否位于应用锚点之下，返回命中的锚点。
    static func appAnchor(containing path: String) -> String? {
        appAnchors.first { path.hasPrefix($0 + "/") }
    }

    static func requiresPrivilege(for path: String) -> Bool {
        let systemLike = path.hasPrefix("/Library/")
            || path.hasPrefix("/System/")
            || path.hasPrefix("/private/var/")
            || path.hasPrefix("/private/tmp/")
        guard systemLike else { return false }
        let parent = (path as NSString).deletingLastPathComponent
        return !FileManager.default.isWritableFile(atPath: parent)
    }

    static func isSymbolicLink(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
            return true
        }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           attributes[.type] as? FileAttributeType == .typeSymbolicLink {
            return true
        }
        return false
    }

    // MARK: - 卸载器专用裁决

    /// 卸载器裁决：允许把「用户自行安装的应用」及其关联文件移入废纸篓。
    ///
    /// 与通用裁决的差异仅在于放开了 /Applications 与 ~/Applications 下的 .app
    /// 以及一批用户级关联目录；系统路径、符号链接、用户数据名仍然拒绝。
    static func evaluateAllowingUninstall(_ url: URL) -> PolicyDecision {
        let path = url.standardizedFileURL.path

        guard path != "/", path != homePath else {
            return .deny("不允许操作磁盘根目录或用户主目录")
        }
        if isSymbolicLink(url) {
            return .deny("符号链接不参与清理")
        }

        // 1) 关联文件优先：位于用户级关联目录内的一律按关联文件处理。
        //    必须先于 .app 判断——否则 ~/Library/Caches/com.example.app 这类
        //    「bundle id 形状」的缓存目录会被误判成应用包而拒绝。
        let allowedPrefixes = [
            home("Library/Application Support"),
            home("Library/Caches"),
            home("Library/Preferences"),
            home("Library/Logs"),
            home("Library/Containers"),
            home("Library/Group Containers"),
            home("Library/Saved Application State"),
            home("Library/WebKit"),
            home("Library/HTTPStorages"),
            home("Library/Application Scripts"),
            home("Library/LaunchAgents"),
        ]
        if allowedPrefixes.contains(where: { path.hasPrefix($0 + "/") }) {
            let name = url.lastPathComponent.lowercased()
            if forbiddenNames.contains(name) || name.hasPrefix("profile ") {
                return .deny("该名称属于用户数据，不能删除")
            }
            return .allow(privileged: false)
        }

        // 2) 应用包：只允许 /Applications 与 ~/Applications 的直接子项
        if url.pathExtension.lowercased() == "app" {
            let parent = url.deletingLastPathComponent().standardizedFileURL.path
            let allowedParents = [home("Applications"), "/Applications"]
            guard allowedParents.contains(parent) else {
                return .deny("只允许卸载 /Applications 与 ~/Applications 下直接安装的应用")
            }
            return .allow(privileged: requiresPrivilege(for: path))
        }

        return .deny("不在允许卸载的路径范围内")
    }

    // MARK: - 用户显式选择文件

    /// 用户在「大文件 / 重复文件」等界面中显式选择的普通文件——允许**移入废纸篓**。
    ///
    /// 限定在标准的用户文件夹内，且必须是普通文件（非符号链接、非目录），
    /// 这样既不会碰系统路径，也不会误伤资料库与钥匙串。
    static func evaluateUserSelectedFile(_ url: URL) -> PolicyDecision {
        let path = url.standardizedFileURL.path

        guard path != "/", path != homePath else {
            return .deny("不允许操作磁盘根目录或用户主目录")
        }
        if isSymbolicLink(url) {
            return .deny("符号链接不参与清理")
        }

        let roots = [
            home("Downloads"), home("Documents"), home("Desktop"),
            home("Movies"), home("Music"), home("Pictures"), home("Public"),
        ]
        guard roots.contains(where: { path.hasPrefix($0 + "/") }) else {
            return .deny("仅支持在用户标准文件夹内移动文件")
        }

        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        guard values?.isRegularFile == true else {
            return .deny("仅支持普通文件")
        }
        return .allow(privileged: false)
    }

    // MARK: - 隐私清理裁决

    /// 隐私清理：只允许清理 PrivacyCatalog 中显式枚举的路径，且调用方一律移入废纸篓。
    static func evaluatePrivacy(_ url: URL) -> PolicyDecision {
        let path = url.standardizedFileURL.path
        guard path != "/", path != homePath else {
            return .deny("不允许操作磁盘根目录或用户主目录")
        }
        if isSymbolicLink(url) {
            return .deny("符号链接不参与清理")
        }
        guard PrivacyCatalog.isPrivacyPath(path) else {
            return .deny("不在隐私清理清单内")
        }
        return .allow(privileged: false)
    }
}