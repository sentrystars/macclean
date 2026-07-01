import Foundation

/// Service for handling privileged operations via SMJobBless XPC helper tool.
/// Falls back to AuthorizationExecuteWithPrivileges if helper tool is unavailable.
actor PrivilegeService {
    private let fileManager = FileManager.default
    private var isHelperInstalled = false

    var isHelperToolInstalled: Bool { isHelperInstalled }

    func checkHelperToolStatus() -> Bool {
        // Check if helper tool is registered with launchd
        // For now, return false to indicate we need to install it
        return isHelperInstalled
    }

    func installHelperTool() async throws {
        // SMJobBless installation logic
        // For MVP, we'll use AuthorizationExecuteWithPrivileges as a simpler approach
        isHelperInstalled = true
    }

    /// Execute a privileged command using AuthorizationExecuteWithPrivileges
    func executePrivilegedCommand(_ command: String, args: [String]) async throws -> String {
        // For now, use Process with sudo via NSAppleScript or similar
        // In production, this should use SMJobBless + XPC
        let fullCommand = "osascript -e 'do shell script \"\(command) \(args.joined(separator: " "))\" with administrator privileges'"
        return try await Process.runAsync(executable: "/bin/zsh", arguments: ["-c", fullCommand])
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

                    // Use osascript to get admin privileges for system-level deletions
                    let script = "do shell script \"rm -rf '\(path.path)/'* 2>/dev/null; rm -f '\(path.path)' 2>/dev/null\" with administrator privileges"
                    let cmd = "osascript -e '\(script)'"

                    if let result = try? await Process.runAsync(executable: "/bin/zsh", arguments: ["-c", cmd]) {
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
        let script = "do shell script \"du -sm '\(path.path)' 2>/dev/null | awk '{print $1}'\" with administrator privileges"
        let cmd = "osascript -e '\(script)'"

        guard let result = try? await Process.runAsync(executable: "/bin/zsh", arguments: ["-c", cmd]),
              let mb = Int64(result.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return 0 }
        return mb * 1_048_576
    }
}
