import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var cleanupVM = CleanupViewModel()
    @State private var showSmartScan = false
    @Environment(AppViewModel.self) private var appVM

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
                    } else if viewModel.isScanning {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, minHeight: 120)
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .font(.largeTitle.bold())
                if let info = viewModel.storageInfo {
                    let used = FileSizeFormatter.string(from: info.usedBytes)
                    let total = FileSizeFormatter.string(from: info.totalBytes)
                    Text("\(used) used of \(total)")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                } else {
                    Text("Storage overview at a glance")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer()
            if let info = viewModel.storageInfo {
                StorageDonutChart(
                    segments: [
                        StorageSegment(value: Double(info.usedBytes), color: .storageUsed, label: "Used"),
                        StorageSegment(value: Double(info.freeBytes), color: .storageFree, label: "Free"),
                    ],
                    size: 80,
                    lineWidth: 12
                )
            }
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
                    HStack(spacing: 12) {
                        if let last = viewModel.lastRefreshed {
                            Text(last, style: .relative)
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            + Text(" ago")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task { await viewModel.refreshStorageInfo() }
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack(spacing: 32) {
                StorageDonutChart(
                    segments: [
                        StorageSegment(value: Double(info.usedBytes), color: .storageUsed, label: "Used"),
                        StorageSegment(value: Double(info.freeBytes), color: .storageFree, label: "Free"),
                    ],
                    size: 140
                )

                VStack(alignment: .leading, spacing: 12) {
                    statRow(label: "Total", value: FileSizeFormatter.string(from: info.totalBytes), color: .textPrimary)
                    statRow(label: "Used", value: FileSizeFormatter.string(from: info.usedBytes), color: .storageUsed)
                    statRow(label: "Free", value: FileSizeFormatter.string(from: info.freeBytes), color: .riskSafe)
                    if let cache = info.cacheBytes {
                        statRow(label: "Caches", value: FileSizeFormatter.string(from: cache), color: .orange)
                    }
                    if let trash = info.trashBytes {
                        statRow(label: "Trash", value: FileSizeFormatter.string(from: trash), color: .red)
                    }
                    let known = (info.cacheBytes ?? 0) + (info.trashBytes ?? 0)
                    let other = max(0, info.usedBytes - known)
                    statRow(label: "Other", value: FileSizeFormatter.string(from: other), color: .textSecondary)
                }
            }
            .padding()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .appShadow, radius: 4)
        }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.textSecondary)
                .frame(width: 60, alignment: .leading)
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
                    title: "Deep Clean",
                    subtitle: "System data & more",
                    icon: "trash.circle",
                    color: .orange
                ) {
                    appVM.selectedSidebarItem = .deepCleanup
                }

                quickActionButton(
                    title: "Empty Trash",
                    subtitle: "Free up space",
                    icon: "trash",
                    color: .red
                ) {
                    appVM.selectedSidebarItem = .trash
                }

                quickActionButton(
                    title: "Analyze",
                    subtitle: "Disk usage details",
                    icon: "chart.pie",
                    color: .purple
                ) {
                    appVM.selectedSidebarItem = .storageAnalysis
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
            .shadow(color: .appShadow, radius: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Grid (simplified)
    private var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore Tools")
                .font(.title2.bold())
                .padding(.top, 8)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                ForEach([
                    (icon: "magnifyingglass", title: "Cache Cleanup", color: Color.appAccent, dest: SidebarItem.cacheCleanup),
                    (icon: "trash.circle", title: "Deep Cleanup", color: Color.orange, dest: SidebarItem.deepCleanup),
                    (icon: "chart.pie", title: "Storage Analysis", color: Color.purple, dest: SidebarItem.storageAnalysis),
                    (icon: "trash", title: "Trash Manager", color: Color.red, dest: SidebarItem.trash),
                ], id: \.title) { item in
                    Button {
                        appVM.selectedSidebarItem = item.dest
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.title2)
                                .foregroundColor(item.color)
                            Text(item.title)
                                .font(.headline)
                                .foregroundColor(.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .appShadow, radius: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Smart Scan
    @ViewBuilder
    private var smartScanSection: some View {
        switch cleanupVM.phase {
        case .idle, .scanning:
            scanningProgress
        case .results(let items):
            scanResultsView(items: items)
        case .cleaning(let progress):
            CleanupProgressView(progress: progress, onCancel: { cleanupVM.cancelCleanup() })
        case .complete(let results):
            CleanupResultsView(results: results) {
                withAnimation { showSmartScan = false }
                cleanupVM.reset()
            }
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

    private var scanningProgress: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning caches...")
                .font(.title3.bold())
            Button("Cancel") {
                cleanupVM.cancelScan()
                withAnimation { showSmartScan = false }
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func scanResultsView(items: [ScanItem]) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Smart Scan Results")
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

            HStack(spacing: 12) {
                Button(action: { Task { await cleanupVM.startCleanup() } }) {
                    Label("Clean Selected Items", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(cleanupVM.selectedItems.isEmpty)

                Button("Back") {
                    withAnimation { showSmartScan = false }
                    cleanupVM.reset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
