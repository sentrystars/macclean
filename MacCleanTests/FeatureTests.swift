import Foundation

enum UninstallerTests {

    static func candidatePaths() throws {
        let paths = AppUninstaller.candidateRelativePaths(bundleIdentifier: "com.example.app", appName: "Example")
        try expect(paths.contains("Library/Application Support/com.example.app"))
        try expect(paths.contains("Library/Application Support/Example"))
        try expect(paths.contains("Library/Caches/com.example.app"))
        try expect(paths.contains("Library/Preferences/com.example.app.plist"))
        try expect(paths.contains("Library/Containers/com.example.app"))
        try expect(paths.contains("Library/Saved Application State/com.example.app.savedState"))
        try expect(paths.contains("Library/LaunchAgents/com.example.app.plist"))
        // 不应出现通配或模糊匹配
        try expect(!paths.contains { $0.contains("*") })
    }

    static func allowsApplicationsBundle() throws {
        try expect(CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: "/Applications/Foo.app")).isAllowed)
        try expect(CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: CleanupPolicy.home("Applications/Bar.app"))).isAllowed)
        // 应用包内部文件不允许
        try expect(!CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: "/Applications/Foo.app/Contents/Info.plist")).isAllowed)
        // 非 /Applications 下的 .app 不允许
        try expect(!CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: CleanupPolicy.home("Documents/Evil.app"))).isAllowed)
    }

    static func deniesSystemPaths() throws {
        try expect(!CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: "/System/Applications/Safari.app")).isAllowed)
        try expect(!CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: "/Applications/Foo.app/Contents")).isAllowed)
        try expect(!CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: CleanupPolicy.home("Library/Keychains/login.keychain-db"))).isAllowed)
    }

    static func allowsAssociatedFiles() throws {
        try expect(CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: CleanupPolicy.home("Library/Caches/com.example.app"))).isAllowed)
        try expect(CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: CleanupPolicy.home("Library/Preferences/com.example.app.plist"))).isAllowed)
        try expect(!CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: CleanupPolicy.home("Library/Safari/History.db"))).isAllowed)
        // 回归：bundle id 形状的缓存目录不能被误判为应用包
        try expect(CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: CleanupPolicy.home("Library/Caches/com.example.app"))).isAllowed)
        try expect(CleanupPolicy.evaluateAllowingUninstall(URL(fileURLWithPath: CleanupPolicy.home("Library/Preferences/com.example.app.plist"))).isAllowed)
    }
}

enum UserFilePolicyTests {

    static func rules() throws {
        // 纯规则断言（不需要写权限）
        try expect(!CleanupPolicy.evaluateUserSelectedFile(URL(fileURLWithPath: CleanupPolicy.home("Library/Preferences/x.plist"))).isAllowed)
        try expect(!CleanupPolicy.evaluateUserSelectedFile(URL(fileURLWithPath: "/etc/hosts")).isAllowed)
        try expect(!CleanupPolicy.evaluateUserSelectedFile(URL(fileURLWithPath: "/")).isAllowed)
        try expect(!CleanupPolicy.evaluateUserSelectedFile(URL(fileURLWithPath: CleanupPolicy.home("Downloads"))).isAllowed, "根目录本身不允许")

        // 允许场景需要在用户文件夹内真实创建文件；受限沙箱下写不进去则跳过
        let downloads = URL(fileURLWithPath: CleanupPolicy.home("Downloads"))
        let probe = downloads.appendingPathComponent(".macclean-test-\(UUID().uuidString).bin")
        do {
            try Data("hello".utf8).write(to: probe)
        } catch {
            print("      （跳过 allow 断言：当前环境不允许写入 ~/Downloads）")
            return
        }
        defer { try? FileManager.default.removeItem(at: probe) }
        try expect(CleanupPolicy.evaluateUserSelectedFile(probe).isAllowed, "Downloads 下的普通文件应允许")
    }
}

enum PrivacyPolicyTests {

    static func whitelist() throws {
        // 清单内路径允许
        try expect(CleanupPolicy.evaluatePrivacy(URL(fileURLWithPath: CleanupPolicy.home("Library/Application Support/Google/Chrome/Default/History"))).isAllowed)
        try expect(CleanupPolicy.evaluatePrivacy(URL(fileURLWithPath: CleanupPolicy.home("Library/Safari/History.db"))).isAllowed)
        // 清单外一律拒绝
        try expect(!CleanupPolicy.evaluatePrivacy(URL(fileURLWithPath: CleanupPolicy.home("Library/Application Support/Google/Chrome/Default/Bookmarks"))).isAllowed)
        try expect(!CleanupPolicy.evaluatePrivacy(URL(fileURLWithPath: CleanupPolicy.home("Library/Preferences/com.apple.finder.plist"))).isAllowed)
        try expect(!CleanupPolicy.evaluatePrivacy(URL(fileURLWithPath: "/Library/Caches/x")).isAllowed)
    }
}

enum DuplicateTests {

    static func hashing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("macclean-dup-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let a = root.appendingPathComponent("a.bin")
        let b = root.appendingPathComponent("b.bin")
        let c = root.appendingPathComponent("c.bin")
        let payload = Data(repeating: 0x7A, count: 3 * 1_048_576)  // 3MB，跨越多个读取块
        try payload.write(to: a)
        try payload.write(to: b)
        try Data("different".utf8).write(to: c)

        let hashA = try expectNotNil(DuplicateFinder.sha256(of: a))
        let hashB = try expectNotNil(DuplicateFinder.sha256(of: b))
        let hashC = try expectNotNil(DuplicateFinder.sha256(of: c))
        try expectEqual(hashA, hashB, "相同内容应产生相同哈希")
        try expect(hashA != hashC, "不同内容应产生不同哈希")
    }

    static func groupMath() throws {
        let files = [
            DuplicateFile(url: URL(fileURLWithPath: "/tmp/x1"), sizeBytes: 100, modified: Date(timeIntervalSince1970: 100)),
            DuplicateFile(url: URL(fileURLWithPath: "/tmp/x2"), sizeBytes: 100, modified: Date(timeIntervalSince1970: 200)),
            DuplicateFile(url: URL(fileURLWithPath: "/tmp/x3"), sizeBytes: 100, modified: Date(timeIntervalSince1970: 300)),
        ]
        let group = DuplicateGroup(id: "hash", sizeBytes: 100, files: files)
        try expectEqual(group.count, 3)
        try expectEqual(group.wastedBytes, 200)
        try expectEqual(group.keepCandidate?.url.path, "/tmp/x1", "应保留最早修改的一份")
    }
}