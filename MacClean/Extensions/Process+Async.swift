import Foundation
import os

/// 命令执行结果。
struct CommandResult: Sendable {
    let standardOutput: String
    let standardError: String
    let exitCode: Int32

    var succeeded: Bool { exitCode == 0 }

    var combinedOutput: String {
        standardError.isEmpty ? standardOutput : standardOutput + "\n" + standardError
    }
}

enum ProcessError: Error, LocalizedError {
    case executableNotFound(String)
    case launchFailed(String, String)
    case timedOut(String, TimeInterval)
    case nonZeroExit(String, Int32, String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path): return "可执行文件不存在：\(path)"
        case .launchFailed(let path, let message): return "无法启动 \(path)：\(message)"
        case .timedOut(let path, let seconds): return "\(path) 执行超时（\(Int(seconds)) 秒）"
        case .nonZeroExit(let path, let code, let message):
            return "\(path) 退出码 \(code)：\(message.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}

/// 跨并发域共享的进程状态容器（Process/Pipe 本身不是 Sendable）。
private final class ProcessBox: @unchecked Sendable {
    let process = Process()
    let outPipe = Pipe()
    let errPipe = Pipe()
    private let timedOutLock = OSAllocatedUnfairLock(initialState: false)

    var didTimeOut: Bool {
        get { timedOutLock.withLock { $0 } }
        set { timedOutLock.withLock { $0 = newValue } }
    }
}

extension Process {
    /// 异步执行外部命令。
    ///
    /// 与旧实现的关键差异：
    /// - stdout/stderr 使用**独立管道并在退出前持续读取**，避免大于 64KB 输出时死锁；
    /// - 不再调用阻塞式的 waitUntilExit()，改用 terminationHandler + continuation；
    /// - 支持超时（先 SIGTERM，宽限后 SIGKILL）。
    static func run(
        executable: String,
        arguments: [String] = [],
        timeout: TimeInterval = 120,
        environment: [String: String]? = nil
    ) async throws -> CommandResult {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw ProcessError.executableNotFound(executable)
        }

        let box = ProcessBox()
        box.process.executableURL = URL(fileURLWithPath: executable)
        box.process.arguments = arguments
        if let environment {
            var merged = ProcessInfo.processInfo.environment
            merged.merge(environment) { _, new in new }
            box.process.environment = merged
        }
        box.process.standardOutput = box.outPipe
        box.process.standardError = box.errPipe

        do {
            try box.process.run()
        } catch {
            throw ProcessError.launchFailed(executable, error.localizedDescription)
        }

        // 关键：必须在等待退出**之前**开始读取。
        // 否则超过管道缓冲（64KB）的输出会让子进程阻塞在 write 上永不退出。
        let outTask = Task.detached(priority: .utility) { box.outPipe.fileHandleForReading.readDataToEndOfFile() }
        let errTask = Task.detached(priority: .utility) { box.errPipe.fileHandleForReading.readDataToEndOfFile() }

        let watchdog = Task.detached(priority: .utility) { [box, timeout, executable] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
            guard box.process.isRunning else { return }
            box.didTimeOut = true
            AppLog.maintenance.error("\(executable, privacy: .public) 超时，发送 SIGTERM")
            box.process.terminate()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if box.process.isRunning {
                kill(box.process.processIdentifier, SIGKILL)
            }
        }

        // 在独立任务中阻塞等待，避免卡住调用方。
        let status = await Task.detached(priority: .utility) { () -> Int32 in
            box.process.waitUntilExit()
            return box.process.terminationStatus
        }.value

        let outData = await outTask.value
        let errData = await errTask.value
        watchdog.cancel()

        if box.didTimeOut {
            throw ProcessError.timedOut(executable, timeout)
        }

        return CommandResult(
            standardOutput: String(data: outData, encoding: .utf8) ?? "",
            standardError: String(data: errData, encoding: .utf8) ?? "",
            exitCode: status
        )
    }

    /// 执行命令并在退出码非 0 时抛出，返回标准输出。
    @discardableResult
    static func runChecked(
        executable: String,
        arguments: [String] = [],
        timeout: TimeInterval = 120
    ) async throws -> String {
        let result = try await run(executable: executable, arguments: arguments, timeout: timeout)
        guard result.succeeded else {
            throw ProcessError.nonZeroExit(executable, result.exitCode, result.combinedOutput)
        }
        return result.standardOutput
    }

    /// 非阻塞地检测命令是否存在（which 查找）。
    static func commandExists(_ command: String) async -> Bool {
        let candidates = ["/usr/bin/which", "/bin/which"]
        guard let which = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return false
        }
        guard let result = try? await run(executable: which, arguments: [command], timeout: 10) else {
            return false
        }
        return result.succeeded && !result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}