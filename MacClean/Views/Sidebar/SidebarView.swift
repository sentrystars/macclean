import SwiftUI

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        List(SidebarItem.allCases, id: \.self, selection: Bindable(appVM).selectedSidebarItem) { item in
            Label(item.displayName, systemImage: item.iconName)
                .font(.body)
                .padding(.vertical, 4)
        }
        .listStyle(.sidebar)
        .navigationTitle("MacClean")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}
