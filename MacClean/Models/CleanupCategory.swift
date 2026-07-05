import SwiftUI

enum RiskLevel: String, Codable, Sendable {
    case safe
    case caution
    case warning
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

    var displayName: String {
        switch self {
        case .userCaches: return "User Caches"
        case .systemCaches: return "System Caches"
        case .userLogs: return "User Logs"
        case .systemLogs: return "System Logs"
        case .appCaches: return "App Caches"
        case .claudeVM: return "Claude VM Images"
        case .xcodeData: return "Xcode Data"
        case .iosSimulators: return "iOS Simulators"
        case .dnsCache: return "DNS Cache"
        case .trash: return "Trash"
        case .systemTemp: return "System Temp Files"
        case .containerCaches: return "Container Caches"
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
        }
    }

    var requiresSudo: Bool {
        switch self {
        case .systemCaches, .systemLogs, .systemTemp, .dnsCache:
            return true
        default:
            return false
        }
    }

    var riskLevel: RiskLevel {
        switch self {
        case .claudeVM, .xcodeData, .iosSimulators:
            return .caution
        case .dnsCache, .systemTemp:
            return .caution
        case .trash:
            return .safe
        default:
            return .safe
        }
    }

    var description: String {
        switch self {
        case .userCaches: return "Application cache files that can be safely regenerated"
        case .systemCaches: return "System-level cache files (requires admin access)"
        case .userLogs: return "User application log files"
        case .systemLogs: return "System log files (requires admin access)"
        case .appCaches: return "Caches from Claude, ChatGPT, browsers, and IDEs"
        case .claudeVM: return "Claude VM disk images (compressed backup preserved)"
        case .xcodeData: return "DerivedData, device support, and archives"
        case .iosSimulators: return "Unavailable iOS simulator runtimes"
        case .dnsCache: return "Flush DNS cache to resolve network issues"
        case .trash: return "Items in the trash bin"
        case .systemTemp: return "Temporary system files older than 1 day"
        case .containerCaches: return "App sandbox container caches"
        }
    }

    var sidebarDestination: SidebarItem {
        switch self {
        case .trash: return .trash
        case .claudeVM, .xcodeData, .iosSimulators, .dnsCache, .systemTemp:
            return .deepCleanup
        default:
            return .cacheCleanup
        }
    }
}
