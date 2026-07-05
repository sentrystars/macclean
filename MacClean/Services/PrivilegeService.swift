import Foundation

/// Service for handling privileged operations via osascript with admin rights.
actor PrivilegeService {
    private let fileManager = FileManager.default
    private var isHelperInstalled = false

    var isHelperToolInstalled: Bool { isHelperInstalled }

    func checkHelperToolStatus() -> Bool {
        return isHelperInstalled
    }

    func installHelperTool() async throws {
        isHelperInstalled = true
    }

    /// Write AppleScript to a temp file and run with osascript (no shell wrapping).
    private func runPrivilegedShell(_ command: String) async throws -> String {
        // Escape for AppleScript string within do shell script "..."
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).scpt")
        try source.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try await Process.runAsync(executable: "/usr/bin/osascript", arguments: [tempURL.path])
    }

    /// Remove items at system paths that require privileged access
    func removePrivilegedItems(at paths: [URL]) -> AsyncStream<CleanProgress> {
        AsyncStream { continuation in
            Task {
                let total = paths.count
                var cleaned = 0
                var freed: Int64 = 0

                for path in paths {
                    let progress = CleanProgress(
                        phase: "Cleaning system files...",
                        currentItem: path.lastPathComponent,
                        itemsCleaned: cleaned,
                        totalItems: total,
                        bytesFreed: freed
                    )
                    continuation.yield(progress)

                    let escapedPath = path.path
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                    let cmd = "rm -rf \"\(escapedPath)\" 2>/dev/null"

                    if (try? await runPrivilegedShell(cmd)) != nil {
                        freed += fileManager.directorySize(at: path)
                        cleaned += 1
                    }
                }

                continuation.yield(CleanProgress(
                    phase: "Complete",
                    currentItem: "",
                    itemsCleaned: cleaned,
                    totalItems: total,
                    bytesFreed: freed
                ))
                continuation.finish()
            }
        }
    }

    /// Get directory size for a system path requiring privileges
    func getPrivilegedDirectorySize(at path: URL) async -> Int64 {
        let escapedPath = path.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let cmd = "du -sm \"\(escapedPath)\" 2>/dev/null | awk '{print $1}'"

        guard let result = try? await runPrivilegedShell(cmd),
              let mb = Int64(result.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return 0 }
        return mb * 1_048_576
    }
}
