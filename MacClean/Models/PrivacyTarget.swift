import Foundation

/// 隐私清理项：路径白名单由代码显式枚举，不做任何通配。
struct PrivacyTarget: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let group: String
    let detail: String
    /// 需要先退出的应用 bundle id。
    let requiredClosedBundleIDs: [String]
    let relativePaths: [String]

    var urls: [URL] {
        relativePaths.map { URL(fileURLWithPath: CleanupPolicy.home($0)) }
    }

    var isDestructive: Bool { true }
}

enum PrivacyCatalog {

    static let targets: [PrivacyTarget] = [
        PrivacyTarget(
            id: "recent-items",
            name: "最近使用项目",
            group: "系统",
            detail: "Finder / 各应用的「最近打开」记录",
            requiredClosedBundleIDs: [],
            relativePaths: ["Library/Application Support/com.apple.sharedfilelist"]
        ),
        PrivacyTarget(
            id: "safari-history",
            name: "Safari 历史记录",
            group: "Safari",
            detail: "浏览历史数据库（退出 Safari 后执行）",
            requiredClosedBundleIDs: ["com.apple.Safari"],
            relativePaths: [
                "Library/Safari/History.db",
                "Library/Safari/History.db-wal",
                "Library/Safari/History.db-shm",
            ]
        ),
        PrivacyTarget(
            id: "safari-cache",
            name: "Safari 缓存与网站数据",
            group: "Safari",
            detail: "页面缓存与本地网站数据（部分网站需要重新登录）",
            requiredClosedBundleIDs: ["com.apple.Safari"],
            relativePaths: [
                "Library/Caches/com.apple.Safari",
                "Library/WebKit/com.apple.Safari",
            ]
        ),
        PrivacyTarget(
            id: "chrome-history",
            name: "Chrome 历史与输入记录",
            group: "Chrome",
            detail: "浏览历史、表单自动填充（退出 Chrome 后执行）",
            requiredClosedBundleIDs: ["com.google.Chrome"],
            relativePaths: [
                "Library/Application Support/Google/Chrome/Default/History",
                "Library/Application Support/Google/Chrome/Default/History-journal",
                "Library/Application Support/Google/Chrome/Default/Web Data",
            ]
        ),
        PrivacyTarget(
            id: "chrome-cookies",
            name: "Chrome Cookie",
            group: "Chrome",
            detail: "网站登录状态，清理后需要重新登录",
            requiredClosedBundleIDs: ["com.google.Chrome"],
            relativePaths: [
                "Library/Application Support/Google/Chrome/Default/Cookies",
                "Library/Application Support/Google/Chrome/Default/Cookies-journal",
            ]
        ),
        PrivacyTarget(
            id: "chrome-cache",
            name: "Chrome 缓存",
            group: "Chrome",
            detail: "页面与代码缓存，可安全清理",
            requiredClosedBundleIDs: ["com.google.Chrome"],
            relativePaths: [
                "Library/Application Support/Google/Chrome/Default/Cache",
                "Library/Application Support/Google/Chrome/Default/Code Cache",
                "Library/Application Support/Google/Chrome/Default/GPUCache",
            ]
        ),
        PrivacyTarget(
            id: "brave-history",
            name: "Brave 历史与 Cookie",
            group: "Brave",
            detail: "浏览历史与 Cookie（退出 Brave 后执行）",
            requiredClosedBundleIDs: ["com.brave.Browser"],
            relativePaths: [
                "Library/Application Support/BraveSoftware/Brave-Browser/Default/History",
                "Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies",
                "Library/Application Support/BraveSoftware/Brave-Browser/Default/Web Data",
            ]
        ),
        PrivacyTarget(
            id: "brave-cache",
            name: "Brave 缓存",
            group: "Brave",
            detail: "页面与代码缓存",
            requiredClosedBundleIDs: ["com.brave.Browser"],
            relativePaths: [
                "Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache",
                "Library/Application Support/BraveSoftware/Brave-Browser/Default/Code Cache",
            ]
        ),
    ]

    /// 隐私清理允许触碰的路径集合（精确匹配或目录前缀）。
    static let allowedPathPrefixes: [String] = targets
        .flatMap(\.relativePaths)
        .map { CleanupPolicy.home($0) }

    static func isPrivacyPath(_ path: String) -> Bool {
        allowedPathPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}
