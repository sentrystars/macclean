import SwiftUI

enum RiskLevel: String, Codable, Sendable, CaseIterable {
    case safe
    case caution
    case warning

    var displayName: String {
        switch self {
        case .safe: return String(localized: "安全")
        case .caution: return String(localized: "谨慎")
        case .warning: return String(localized: "高风险")
        }
    }
}

enum CleanupCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    var id: String { rawValue }
    case userCaches
    case systemCaches
    case userLogs
    case systemLogs
    case appCaches
    case claudeVM
    case xcodeData
    case iosSimulators
    case dnsCache
    case trash
    case systemTemp
    case containerCaches
    case systemData
    case macOSSystem
    case developerCaches

    /// 归入三大存储桶
    var group: String {
        switch self {
        case .developerCaches:
            return "Developer"
        case .userCaches, .systemCaches, .appCaches, .containerCaches:
            return "Application Caches"
        case .systemData, .userLogs, .systemLogs, .systemTemp, .dnsCache, .xcodeData, .iosSimulators, .claudeVM, .trash:
            return "System Data"
        case .macOSSystem:
            return "macOS"
        }
    }

    var displayName: String {
        switch self {
        case .userCaches: return String(localized: "User Caches")
        case .systemCaches: return String(localized: "System Caches")
        case .userLogs: return String(localized: "User Logs")
        case .systemLogs: return String(localized: "System Logs")
        case .appCaches: return String(localized: "App Caches")
        case .claudeVM: return String(localized: "Claude VM Images")
        case .xcodeData: return String(localized: "Xcode Data")
        case .iosSimulators: return String(localized: "iOS Simulators")
        case .dnsCache: return String(localized: "DNS Cache")
        case .trash: return String(localized: "Trash")
        case .systemTemp: return String(localized: "System Temp Files")
        case .containerCaches: return String(localized: "Container Caches")
        case .systemData: return String(localized: "System Data")
        case .macOSSystem: return String(localized: "macOS System")
        case .developerCaches: return String(localized: "Developer Caches")
        }
    }

    var iconName: String {
        switch self {
        case .userCaches: return "folder"
        case .systemCaches: return "gearshape.2"
        case .userLogs: return "doc.text"
        case .systemLogs: return "doc.text.magnifyingglass"
        case .appCaches: return "app"
        case .claudeVM: return "desktopcomputer"
        case .xcodeData: return "hammer"
        case .iosSimulators: return "iphone"
        case .dnsCache: return "antenna.radiowaves.left.and.right"
        case .trash: return "trash"
        case .systemTemp: return "clock.arrow.circlepath"
        case .containerCaches: return "square.grid.3x3"
        case .systemData: return "externaldrive.fill"
        case .macOSSystem: return "menubar.dock.rectangle"
        case .developerCaches: return "terminal"
        }
    }

    var color: Color {
        switch self {
        case .userCaches: return .blue
        case .systemCaches: return .orange
        case .userLogs: return .gray
        case .systemLogs: return .gray
        case .appCaches: return .purple
        case .claudeVM: return .green
        case .xcodeData: return .cyan
        case .iosSimulators: return .indigo
        case .dnsCache: return .yellow
        case .trash: return .red
        case .systemTemp: return .orange
        case .containerCaches: return .teal
        case .systemData: return .brown
        case .macOSSystem: return .secondary
        case .developerCaches: return .mint
        }
    }

    var requiresSudo: Bool {
        switch self {
        case .systemCaches, .systemLogs, .systemTemp, .systemData:
            return true
        default:
            return false
        }
    }

    var riskLevel: RiskLevel {
        switch self {
        case .claudeVM, .xcodeData, .iosSimulators:
            return .caution
        case .dnsCache, .systemTemp, .systemData, .macOSSystem,
             .systemCaches, .systemLogs, .containerCaches:
            return .caution
        case .userCaches, .userLogs, .appCaches, .trash, .developerCaches:
            return .safe
        }
    }

    /// 默认是否勾选（只有 safe 才默认选中）。
    var isSelectedByDefault: Bool { riskLevel == .safe }

    var description: String {
        switch self {
        case .userCaches: return String(localized: "可安全再生的应用缓存文件")
        case .systemCaches: return String(localized: "系统级缓存（需要管理员权限）")
        case .userLogs: return String(localized: "用户应用日志文件")
        case .systemLogs: return String(localized: "系统日志文件（需要管理员权限）")
        case .appCaches: return String(localized: "浏览器与 IDE 的缓存目录（不含配置数据）")
        case .claudeVM: return String(localized: "Claude VM 磁盘镜像（保留 .zst 压缩备份）")
        case .xcodeData: return String(localized: "DerivedData、设备支持与 Archives")
        case .iosSimulators: return String(localized: "不可用的 iOS 模拟器运行时")
        case .dnsCache: return String(localized: "刷新 DNS 缓存以修复网络问题")
        case .trash: return String(localized: "废纸篓中的项目")
        case .systemTemp: return String(localized: "超过保留天数的临时文件")
        case .containerCaches: return String(localized: "沙盒容器缓存")
        case .systemData: return String(localized: "系统缓存、临时文件、iOS 备份")
        case .macOSSystem: return String(localized: "macOS 字体缓存与诊断报告")
        case .developerCaches: return String(localized: "开发者缓存")
        }
    }
}