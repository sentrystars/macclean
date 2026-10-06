import Foundation
import os

/// 统一日志出口。所有清理/特权/扫描行为都会留下结构化日志，便于排查。
enum AppLog {
    private static let subsystem = "com.macclean.app"

    static let scan = Logger(subsystem: subsystem, category: "scan")
    static let cleanup = Logger(subsystem: subsystem, category: "cleanup")
    static let privileged = Logger(subsystem: subsystem, category: "privileged")
    static let diagnostics = Logger(subsystem: subsystem, category: "diagnostics")
    static let maintenance = Logger(subsystem: subsystem, category: "maintenance")

    /// 记录被安全策略拒绝的路径，便于用户回溯"为什么没被清理"。
    static func denied(_ path: String, reason: String) {
        cleanup.notice("policy denied \(path, privacy: .public) reason=\(reason, privacy: .public)")
    }

    static func failed(_ path: String, error: String) {
        cleanup.error("cleanup failed \(path, privacy: .public) error=\(error, privacy: .public)")
    }
}
