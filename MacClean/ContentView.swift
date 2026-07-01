import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailView: some View {
        switch appVM.selectedSidebarItem {
        case .dashboard:
            DashboardView()
        case .cacheCleanup:
            CleanupCategoriesView()
        case .deepCleanup:
            DeepCleanView()
        case .storageAnalysis:
            DiagnosticsView()
        case .trash:
            TrashView()
        }
    }
}
