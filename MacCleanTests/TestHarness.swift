import Foundation

/// 轻量测试断言（不依赖 XCTest）。
struct TestFailure: Error, CustomStringConvertible {
    let message: String
    let file: String
    let line: UInt
    var description: String { "\(file):\(line) \(message)" }
}

func expect(
    _ condition: Bool,
    _ message: String = "断言失败",
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    if !condition {
        throw TestFailure(message: message, file: "\(file)", line: line)
    }
}

func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    if actual != expected {
        throw TestFailure(message: message.isEmpty ? "期望 \(expected)，实际 \(actual)" : "\(message)：期望 \(expected)，实际 \(actual)", file: "\(file)", line: line)
    }
}

func expectNotNil<T>(
    _ value: T?,
    _ message: String = "不应为 nil",
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> T {
    guard let value else {
        throw TestFailure(message: message, file: "\(file)", line: line)
    }
    return value
}

@main
struct MacCleanTestRunner {
    static func main() async {
        let tests: [(String, () async throws -> Void)] = [
            // CleanupPolicy
            ("policy：允许用户缓存子项", CleanupPolicyTests.allowsUserCacheChild),
            ("policy：禁止删除容器本身", CleanupPolicyTests.deniesContainerItself),
            ("policy：禁止浏览器 Default 目录", CleanupPolicyTests.deniesBrowserDefault),
            ("policy：禁止浏览器 Profile 目录", CleanupPolicyTests.deniesBrowserProfile),
            ("policy：允许 Default 下的缓存叶子", CleanupPolicyTests.allowsCacheLeafInsideDefault),
            ("policy：禁止 Preferences 等用户数据", CleanupPolicyTests.deniesUserDataNames),
            ("policy：禁止应用包", CleanupPolicyTests.deniesAppBundle),
            ("policy：允许废纸篓内容（含 app 包）", CleanupPolicyTests.allowsTrashContents),
            ("policy：禁止系统路径", CleanupPolicyTests.deniesSystemPaths),
            ("policy：禁止白名单外路径", CleanupPolicyTests.deniesOutsideAllowlist),
            ("policy：禁止符号链接", CleanupPolicyTests.deniesSymlink),
            ("policy：sleepimage 不在白名单", CleanupPolicyTests.deniesSleepImage),
            // 解析 / 格式化
            ("tmutil：快照时间解析", SnapshotParsingTests.parsesTimestamp),
            ("tmutil：忽略非快照行", SnapshotParsingTests.ignoresNoise),
            ("格式化：字节显示", FormatterTests.formatsBytes),
            ("选项：排除列表", OptionsTests.exclusionMatching),
            // 模型
            ("模型：风险等级默认继承", ModelTests.riskInheritance),
            ("模型：默认勾选规则", ModelTests.defaultSelection),
            // 文件系统 / 进程
            ("文件：目录大小统计", FileSystemTests.directorySize),
            ("文件：可用容量可读取", FileSystemTests.availableCapacity),
            ("进程：捕获标准输出", ProcessTests.capturesOutput),
            ("进程：非零退出码抛出", ProcessTests.throwsOnNonZeroExit),
            ("进程：大输出不死锁", ProcessTests.largeOutputNoDeadlock),
            ("进程：超时被中断", ProcessTests.timesOut),
            // 新功能
            ("卸载器：关联路径生成", UninstallerTests.candidatePaths),
            ("卸载器：允许 /Applications 应用", UninstallerTests.allowsApplicationsBundle),
            ("卸载器：拒绝系统与内部路径", UninstallerTests.deniesSystemPaths),
            ("卸载器：允许关联文件", UninstallerTests.allowsAssociatedFiles),
            ("大文件/重复文件：用户文件策略", UserFilePolicyTests.rules),
            ("隐私：仅允许清单内路径", PrivacyPolicyTests.whitelist),
            ("重复文件：流式哈希判定", DuplicateTests.hashing),
            ("重复文件：分组统计与保留策略", DuplicateTests.groupMath),
            ("开发者缓存：清单与路径判定", DeveloperCacheTests.catalog),
            ("开发者缓存：清理策略", DeveloperCacheTests.policy),
            ("开发者缓存：分类感知路由", DeveloperCacheTests.routing),
            ("系统数据：构成项定义", SystemDataTests.specs),
            ("系统数据：缺失路径计为 0", SystemDataTests.sizeOfMissingPath),
        ]

        var passed = 0
        var failures: [String] = []

        for (name, body) in tests {
            do {
                try await body()
                passed += 1
                print("PASS  \(name)")
            } catch {
                failures.append("\(name): \(error)")
                print("FAIL  \(name)\n      \(error)")
            }
        }

        print("")
        print("========================================")
        print("通过 \(passed) / \(tests.count)")
        if !failures.isEmpty {
            print("失败：")
            for failure in failures { print(" - \(failure)") }
        }
        print("========================================")
        exit(failures.isEmpty ? 0 : 1)
    }
}