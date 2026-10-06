import Foundation

enum LoginItemScope: String, Sendable, CaseIterable {
    case userAgent
    case globalAgent
    case globalDaemon

    var displayName: String {
        switch self {
        case .userAgent: return "用户启动项"
        case .globalAgent: return "全局启动项"
        case .globalDaemon: return "系统守护进程"
        }
    }

    var requiresPrivilege: Bool { self != .userAgent }
}

struct LoginItem: Identifiable, Sendable {
    let plistURL: URL
    let label: String
    let program: String?
    let runAtLoad: Bool
    let scope: LoginItemScope
    let isLoaded: Bool

    var id: String { plistURL.path }
    var displayName: String { label }

    var programDisplay: String {
        guard let program else { return "—" }
        return (program as NSString).lastPathComponent
    }

    var canToggle: Bool { scope == .userAgent }
}
