import SwiftUI

@main
struct MacCleanApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

@Observable
final class AppViewModel {
    var selectedCategory: CleanupCategory?
    var selectedSidebarItem: SidebarItem = .dashboard
}

enum SidebarItem: String, CaseIterable, Hashable {
    case dashboard
    case cacheCleanup
    case deepCleanup
    case storageAnalysis
    case trash

    var displayName: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .cacheCleanup: return "Cache Cleanup"
        case .deepCleanup: return "Deep Cleanup"
        case .storageAnalysis: return "Storage Analysis"
        case .trash: return "Trash Manager"
        }
    }

    var iconName: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .cacheCleanup: return "folder.badge.gearshape"
        case .deepCleanup: return "trash.circle"
        case .storageAnalysis: return "chart.pie"
        case .trash: return "trash"
        }
    }
}
