import SwiftUI

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var storageInfo: StorageInfo?
    @State private var isLoadingStorage = true

    var body: some View {
        List(selection: Bindable(appVM).selectedSidebarItem) {
            // App branding
            Section {
                Label("MacClean", systemImage: "leaf.fill")
                    .font(.title3.bold())
                    .foregroundColor(.appAccent)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
            }

            // Quick Access
            Section("Quick Access") {
                sidebarItem(.dashboard)
            }

            // Tools
            Section("Tools") {
                sidebarItem(.cacheCleanup)
                sidebarItem(.deepCleanup)
                sidebarItem(.storageAnalysis)
                sidebarItem(.trash)
            }

            // Storage Pressure
            if let info = storageInfo {
                Section("Storage") {
                    storagePressureView(info)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("")
        .task {
            let diagnostic = DiagnosticService()
            storageInfo = try? await diagnostic.getStorageInfo()
            isLoadingStorage = false
        }
    }

    private func sidebarItem(_ item: SidebarItem) -> some View {
        Label(item.displayName, systemImage: item.iconName)
            .font(.body)
            .padding(.vertical, 4)
            .tag(item)
    }

    private func storagePressureView(_ info: StorageInfo) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("Disk Usage")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Spacer()
                let used = FileSizeFormatter.string(from: info.usedBytes)
                let total = FileSizeFormatter.string(from: info.totalBytes)
                Text("\(used) / \(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.progressTrack)
                        .frame(height: 6)

                    Capsule()
                        .fill(pressureColor(percentage: info.usagePercentage))
                        .frame(width: geo.size.width * CGFloat(min(info.usagePercentage, 1.0)))
                        .frame(height: 6)
                        .animation(.easeInOut(duration: 0.5), value: info.usagePercentage)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int(info.usagePercentage * 100))% used")
                    .font(.caption2)
                    .foregroundColor(pressureColor(percentage: info.usagePercentage))
                Spacer()
                if let trash = info.trashBytes, trash > 0 {
                    Text("\(FileSizeFormatter.string(from: trash)) in Trash")
                        .font(.caption2)
                        .foregroundColor(.riskCaution)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func pressureColor(percentage: Double) -> Color {
        switch percentage {
        case 0..<0.6: return .riskSafe
        case 0.6..<0.8: return .riskCaution
        default: return .riskWarning
        }
    }
}
