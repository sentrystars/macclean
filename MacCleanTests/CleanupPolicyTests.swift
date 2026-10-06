import Foundation

enum CleanupPolicyTests {

    private static func path(_ relative: String) -> URL {
        URL(fileURLWithPath: CleanupPolicy.home(relative))
    }

    static func allowsUserCacheChild() throws {
        try expect(CleanupPolicy.evaluate(path("Library/Caches/com.example.app")).isAllowed)
        try expect(CleanupPolicy.evaluate(path("Library/Logs/DiagnosticReports")).isAllowed)
    }

    static func deniesContainerItself() throws {
        try expect(!CleanupPolicy.evaluate(path("Library/Caches")).isAllowed)
        try expect(!CleanupPolicy.evaluate(path("Library/Logs")).isAllowed)
        try expect(!CleanupPolicy.evaluate(URL(fileURLWithPath: CleanupPolicy.homePath)).isAllowed)
        try expect(!CleanupPolicy.evaluate(URL(fileURLWithPath: "/")).isAllowed)
    }

    static func deniesBrowserDefault() throws {
        let url = path("Library/Application Support/Google/Chrome/Default")
        let decision = CleanupPolicy.evaluate(url)
        try expect(!decision.isAllowed, "Chrome Default 必须被拒绝")
    }

    static func deniesBrowserProfile() throws {
        let url = path("Library/Application Support/BraveSoftware/Brave-Browser/Profile 2")
        try expect(!CleanupPolicy.evaluate(url).isAllowed, "浏览器配置文件必须被拒绝")
    }

    static func allowsCacheLeafInsideDefault() throws {
        let cache = path("Library/Application Support/Google/Chrome/Default/Cache")
        try expect(CleanupPolicy.evaluate(cache).isAllowed, "Default 下的 Cache 目录应允许")
        let gpu = path("Library/Application Support/Google/Chrome/Default/Code Cache")
        try expect(CleanupPolicy.evaluate(gpu).isAllowed)
        let prefs = path("Library/Application Support/Google/Chrome/Default/Preferences")
        try expect(!CleanupPolicy.evaluate(prefs).isAllowed, "Preferences 必须被拒绝")
    }

    static func deniesUserDataNames() throws {
        for name in ["Bookmarks", "Cookies", "Web Data", "History", "Login Data"] {
            let url = path("Library/Application Support/Google/Chrome/Default/" + name)
            try expect(!CleanupPolicy.evaluate(url).isAllowed, "\(name) 必须被拒绝")
        }
    }

    static func deniesAppBundle() throws {
        // 缓存目录里形如 bundle id 的 .app 目录只是缓存数据，允许清理
        try expect(CleanupPolicy.evaluate(path("Library/Caches/SomeApp.app")).isAllowed)
        // 但真正的构建产物（.app）不允许直接删除，应当删除其上层项目目录
        let built = path("Library/Developer/Xcode/DerivedData/Foo/Build/Products/Release/Foo.app")
        try expect(!CleanupPolicy.evaluate(built).isAllowed)
    }

    static func allowsTrashContents() throws {
        try expect(CleanupPolicy.evaluate(path(".Trash/SomeApp.app")).isAllowed)
        try expect(CleanupPolicy.evaluate(path(".Trash/我的文件.txt")).isAllowed)
        // 但废纸篓目录本身不能删
        try expect(!CleanupPolicy.evaluate(path(".Trash")).isAllowed)
    }

    static func deniesSystemPaths() throws {
        try expect(!CleanupPolicy.evaluate(URL(fileURLWithPath: "/System/Library/Caches/com.apple.x")).isAllowed)
        try expect(!CleanupPolicy.evaluate(URL(fileURLWithPath: "/usr/bin/ls")).isAllowed)
        try expect(!CleanupPolicy.evaluate(URL(fileURLWithPath: "/Library/LaunchDaemons/com.x.plist")).isAllowed)
    }

    static func deniesOutsideAllowlist() throws {
        try expect(!CleanupPolicy.evaluate(path("Documents/重要文档.pdf")).isAllowed)
        try expect(!CleanupPolicy.evaluate(path("Library/Application Support/Slack")).isAllowed)
        try expect(!CleanupPolicy.evaluate(path("Pictures/照片.jpg")).isAllowed)
    }

    static func deniesSymlink() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("macclean-policy-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("target.txt")
        try "hello".write(to: target, atomically: true, encoding: .utf8)
        let link = directory.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let decision = CleanupPolicy.evaluate(link)
        try expect(!decision.isAllowed, "符号链接必须被拒绝")
        try expect(CleanupPolicy.isSymbolicLink(link))
    }

    static func deniesSleepImage() throws {
        try expect(!CleanupPolicy.evaluate(URL(fileURLWithPath: "/private/var/vm/sleepimage")).isAllowed)
    }
}
