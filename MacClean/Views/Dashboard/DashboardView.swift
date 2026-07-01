import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var cleanupVM = CleanupViewModel()
    @State private var showSmartScan = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                if showSmartScan {
                    smartScanSection
                } else {
                    // Storage Overview
                    if let info = viewModel.storageInfo {
                        storageOverviewSection(info)
                    }

                    // Quick Actions
                    quickActionsSection

                    // Category Grid
                    categoryGridSection
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task {
            await viewModel.refreshStorageInfo()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 48))
                .foregroundColor(.appAccent)
            Text("MacClean")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Clean up your Mac and reclaim disk space")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Storage Overview
    private func storageOverviewSection(_ info: StorageInfo) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Storage Overview")
                    .font(.title2.bold())
                Spacer()
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await viewModel.refreshStorageInfo() }
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(spacing: 32) {
                StorageDonutChart(
                    segments: [
                        StorageSegment(value: Double(info.usedBytes - (info.systemDataBytes ?? 0)), color: .storageUsed, label: "Apps"),
                        StorageSegment(value: Double(info.systemDataBytes ?? 0), color: .storageSystem, label: "System"),
                        StorageSegment(value: Double(info.freeBytes), color: .storageFree, label: "Free"),
                    ],
                    size: 140
                )

                VStack(alignment: .leading, spacing: 12) {
                    statRow(label: "Total", value: FileSizeFormatter.string(from: info.totalBytes), color: .textPrimary)
                    statRow(label: "Used", value: FileSizeFormatter.string(from: info.usedBytes), color: .storageUsed)
                    statRow(label: "System Data", value: info.systemDataBytes.map { FileSizeFormatter.string(from: $0) } ?? "—", color: .storageSystem)
                    statRow(label: "Free", value: FileSizeFormatter.string(from: info.freeBytes), color: .riskSafe)
                    if let cache = info.cacheBytes {
                        statRow(label: "Caches", value: FileSizeFormatter.string(from: cache), color: .orange)
                    }
                    if let trash = info.trashBytes {
                        statRow(label: "Trash", value: FileSizeFormatter.string(from: trash), color: .red)
                    }
                }
            }
            .padding()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4)
        }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.textSecondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .rounded).monospacedDigit())
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title2.bold())

            HStack(spacing: 16) {
                quickActionButton(
                    title: "Smart Scan",
                    subtitle: "Scan all caches",
                    icon: "sparkle.magnifyingglass",
                    color: .appAccent
                ) {
                    withAnimation { showSmartScan = true }
                    await cleanupVM.startScan()
                }

                quickActionButton(
                    title: "Empty Trash",
                    subtitle: "Free up space",
                    icon: "trash",
                    color: .red
                ) {
                    await TrashViewModel().emptyTrash()
                }

                quickActionButton(
                    title: "Analyze Storage",
                    subtitle: "Disk usage details",
                    icon: "chart.pie",
                    color: .purple
                ) {
                    // Navigate to diagnostics - triggered via sidebar selection
                }
            }
        }
    }

    private func quickActionButton(title: String, subtitle: String, icon: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Grid
    private var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cleanup Categories")
                .font(.title2.bold())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                ForEach(CleanupCategory.allCases, id: \.self) { category in
                    NavigationLink(value: SidebarItem.cacheCleanup) {
                        CategoryCardView(category: category, sizeBytes: 0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Smart Scan Results
    private var smartScanSection: some View {
        Group {
            switch cleanupVM.phase {
            case .idle:
                EmptyView()
            case .scanning(let progress):
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.appAccent)
                    Text("Scanning your Mac...")
                        .font(.title2.bold())
                    Text(progress.phase)
                        .foregroundColor(.textSecondary)
                    AnimatedProgressBar(value: progress.fractionCompleted, color: .appAccent)
                        .frame(width: 300)
                    Text("\(progress.filesScanned) files · \(FileSizeFormatter.string(from: progress.bytesFound)) found")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4)

            case .results(let items):
                scanResultsView(items: items)

            case .cleaning(let progress):
                VStack(spacing: 16) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    Text("Cleaning...")
                        .font(.title2.bold())
                    Text(progress.phase)
                        .foregroundColor(.textSecondary)
                    AnimatedProgressBar(value: progress.fractionCompleted, color: .appAccent)
                        .frame(width: 300)
                    Text("\(FileSizeFormatter.string(from: progress.bytesFreed)) freed")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            case .complete(let results):
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.riskSafe)
                    Text("Cleanup Complete!")
                        .font(.title2.bold())
                    let total = results.reduce(0) { $0 + $1.bytesFreed }
                    Text("Total space freed: \(FileSizeFormatter.string(from: total))")
                        .foregroundColor(.textSecondary)

                    Button("Done") {
                        withAnimation {
                            showSmartScan = false
                            cleanupVM.reset()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.riskCaution)
                    Text(message)
                        .foregroundColor(.textSecondary)
                    Button("Try Again") {
                        cleanupVM.reset()
                    }
                }
                .padding()
            }
        }
    }

    private func scanResultsView(items: [ScanItem]) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Scan Results")
                    .font(.title2.bold())
                Spacer()
                let total = items.reduce(0) { $0 + $1.sizeBytes }
                Text(FileSizeFormatter.string(from: total))
                    .font(.title3.bold())
                    .foregroundColor(.appAccent)
            }

            ForEach(items.prefix(20)) { item in
                HStack {
                    Image(systemName: item.category.iconName)
                        .foregroundColor(item.category.color)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text(item.subcategory ?? item.url.lastPathComponent)
                            .font(.body)
                        Text(item.category.displayName)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Text(item.sizeFormatted)
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundColor(.textSecondary)
                    if let modified = item.lastModifiedFormatted {
                        Text(modified)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                .padding(.horizontal)
            }

            Button(action: { Task { await cleanupVM.startCleanup() } }) {
                Label("Clean Selected Items", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(cleanupVM.selectedItems.isEmpty)
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
