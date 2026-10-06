import Foundation

enum FileSystemTests {

    static func directorySize() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("macclean-size-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let data = Data(repeating: 0x41, count: 4096)
        try data.write(to: root.appendingPathComponent("a.bin"))
        try data.write(to: nested.appendingPathComponent("b.bin"))

        let size = FileManager.default.directorySize(at: root)
        try expect(size >= 8192, "目录大小应至少包含两个文件，实际 \(size)")
    }

    static func availableCapacity() throws {
        let capacity = FileManager.default.availableCapacity(for: URL.homeDirectory)
        let value = try expectNotNil(capacity, "应能读取主目录卷容量")
        try expect(value.total > 0)
        try expect(value.free >= 0)
    }
}

enum ProcessTests {

    static func capturesOutput() async throws {
        let result = try await Process.run(executable: "/bin/echo", arguments: ["hello", "world"], timeout: 20)
        try expect(result.succeeded)
        try expectEqual(result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines), "hello world")
    }

    static func throwsOnNonZeroExit() async throws {
        do {
            _ = try await Process.runChecked(executable: "/bin/ls", arguments: ["/definitely/not/here"], timeout: 20)
            throw TestFailure(message: "应当抛出非零退出码错误", file: #filePath, line: #line)
        } catch is ProcessError {
            // 预期
        }
    }

    static func largeOutputNoDeadlock() async throws {
        // 200KB 输出远超 64KB 管道缓冲：旧实现会在此死锁。
        let result = try await Process.run(
            executable: "/usr/bin/head",
            arguments: ["-c", "200000", "/dev/zero"],
            timeout: 60
        )
        try expect(result.succeeded)
        try expect(result.standardOutput.count >= 100_000, "应完整读取大输出，实际 \(result.standardOutput.count)")
    }

    static func timesOut() async throws {
        let started = Date()
        do {
            _ = try await Process.run(executable: "/bin/sleep", arguments: ["30"], timeout: 1)
            throw TestFailure(message: "应当超时", file: #filePath, line: #line)
        } catch ProcessError.timedOut {
            let elapsed = Date().timeIntervalSince(started)
            try expect(elapsed < 15, "超时应在合理时间内返回，实际 \(elapsed)s")
        }
    }
}
