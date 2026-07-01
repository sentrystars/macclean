import Foundation

extension Process {
    /// Run a command and return stdout as a String.
    static func runAsync(executable: String, arguments: [String] = []) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Run a command with sudo via AuthorizationExecuteWithPrivileges equivalent.
    /// For now, runs directly (used for non-sudo commands).
    static func runSystemCommand(_ command: String, args: [String] = []) async throws -> String {
        try await runAsync(executable: command, arguments: args)
    }

    /// Check if a command exists.
    static func commandExists(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try? process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }
}
