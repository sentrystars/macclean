import Foundation

/// 不依赖具体路径的系统维护动作。
enum MaintenanceKind: String, CaseIterable, Sendable, Identifiable {
    case flushDNS
    case thinTimeMachineSnapshots
    case deleteUnavailableSimulators
    case emptyTrash
    case purgeMemory
    case rebuildSpotlightIndex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flushDNS: return String(localized: "刷新 DNS 缓存")
        case .thinTimeMachineSnapshots: return String(localized: "清理 Time Machine 本地快照")
        case .deleteUnavailableSimulators: return String(localized: "删除不可用的 iOS 模拟器")
        case .emptyTrash: return String(localized: "清空废纸篓")
        case .purgeMemory: return String(localized: "释放内存缓存")
        case .rebuildSpotlightIndex: return String(localized: "重建 Spotlight 索引")
        }
    }

    var detail: String {
        switch self {
        case .flushDNS: return String(localized: "重置 DNS 解析缓存，可解决部分网络异常")
        case .thinTimeMachineSnapshots: return String(localized: "删除本地时间机器快照，通常可释放大量空间")
        case .deleteUnavailableSimulators: return String(localized: "移除 xcrun simctl 报告的失效模拟器运行时")
        case .emptyTrash: return String(localized: "永久删除废纸篓中的全部内容")
        case .purgeMemory: return String(localized: "清空文件系统缓存（需要管理员权限）")
        case .rebuildSpotlightIndex: return String(localized: "重建 Spotlight 索引（耗时较长，需要管理员权限）")
        }
    }

    var iconName: String {
        switch self {
        case .flushDNS: return "antenna.radiowaves.left.and.right"
        case .thinTimeMachineSnapshots: return "clock.arrow.circlepath"
        case .deleteUnavailableSimulators: return "iphone.slash"
        case .emptyTrash: return "trash"
        case .purgeMemory: return "memorychip"
        case .rebuildSpotlightIndex: return "magnifyingglass.circle"
        }
    }

    var requiresPrivilege: Bool {
        switch self {
        case .flushDNS, .deleteUnavailableSimulators, .emptyTrash: return false
        case .thinTimeMachineSnapshots, .purgeMemory, .rebuildSpotlightIndex: return true
        }
    }

    var isDestructive: Bool {
        switch self {
        case .emptyTrash, .thinTimeMachineSnapshots: return true
        default: return false
        }
    }
}

/// 维护动作的执行结果。
struct MaintenanceResult: Identifiable, Sendable {
    let id: UUID
    let kind: MaintenanceKind
    let succeeded: Bool
    let message: String
    let freedBytes: Int64

    init(id: UUID = UUID(), kind: MaintenanceKind, succeeded: Bool, message: String, freedBytes: Int64 = 0) {
        self.id = id
        self.kind = kind
        self.succeeded = succeeded
        self.message = message
        self.freedBytes = freedBytes
    }
}