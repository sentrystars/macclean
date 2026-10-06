import SwiftUI

@main
struct MacCleanApp: App {

    @State private var viewModel = AppViewModel()

    init() {
        SettingsKey.registerDefaults()
        AutoCleanScheduler.shared.start()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(viewModel)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("刷新磁盘信息") {
                    Task { await StorageStore.shared.refresh(force: true) }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra("MacClean", systemImage: "leaf.fill") {
            MenuBarView()
                .environment(viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

@Observable
final class AppViewModel {
    var selectedSidebarItem: SidebarItem = .dashboard
}

enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case dashboard
    case cacheCleanup
    case deepCleanup
    case trash
    case uninstaller
    case duplicates
    case privacy
    case storageAnalysis
    case loginItems
    case systemData
    case simulators

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dashboard: return String(localized: "Dashboard")
        case .cacheCleanup: return String(localized: "Cache Cleanup")
        case .deepCleanup: return String(localized: "Deep Cleanup")
        case .storageAnalysis: return String(localized: "Storage Analysis")
        case .trash: return String(localized: "Trash Manager")
        case .uninstaller: return String(localized: "Uninstaller")
        case .duplicates: return String(localized: "Duplicate Finder")
        case .privacy: return String(localized: "Privacy")
        case .loginItems: return String(localized: "Login Items")
        case .systemData: return String(localized: "System Data")
        case .simulators: return String(localized: "Simulators")
        }
    }

    var iconName: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .cacheCleanup: return "folder.badge.gearshape"
        case .deepCleanup: return "trash.circle"
        case .storageAnalysis: return "chart.pie"
        case .trash: return "trash"
        case .uninstaller: return "shippingbox"
        case .duplicates: return "doc.on.doc"
        case .privacy: return "hand.raised"
        case .loginItems: return "power"
        case .systemData: return "internaldrive"
        case .simulators: return "iphone"
        }
    }
}