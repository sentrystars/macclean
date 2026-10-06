import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var cleanupVM = CleanupViewModel()
    @State private var showSmartScan = false
    @State private var showCleanConfirm = false
    @State private var cleanupHistory = CleanupHistory.shared
    @State private var hasFullDiskAccess = true
    @AppStorage(SettingsKey.confirmBeforeClean) private var confirmBeforeClean = true
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if showSmartScan {
                    smartScanSection
                } else {
                    if !hasFullDiskAccess {
                        FullDiskAccessBanner()
                    }

                    if let info = viewModel.storageInfo {
                        storageOverviewSection(info)
                    } else if viewModel.isScanning {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }

                    quickActionsSection

                    if !cleanupHistory.records.isEmpty {
                        recentCleanupSection
                    }

                    categoryGridSection
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appWindowBackground()
        .task {
            // TCC 探测可能触发系统调用，放到后台线程，避免阻塞主线程
            hasFullDiskAccess = await Task.detached(priority: .utility) {
                MaintenanceService().hasFullDiskAccess()
            }.value
            await viewModel.refreshStorageInfo()
        }
        .alert("确认清理", isPresented: $showCleanConfirm) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) {
                Task { await cleanupVM.startCleanup() }
            }
        } message: {
            Text("将永久删除 \(cleanupVM.selectedCount) 个项目，共 \(FileSizeFormatter.string(from: cleanupVM.selectedBytes))。")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .font(.largeTitle.bold())
                if let info = viewModel.storageInfo {
                    Text("已用 \(FileSizeFormatter.string(from: info.usedBytes)) / \(FileSizeFormatter.string(from: info.totalBytes))")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                } else {
                    Text("磁盘概况一览")
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
    }

    // MARK: - Storage

    private func storageOverviewSection(_ info: StorageInfo) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Storage Overview")
                    .font(.title2.bold())
                Spacer()
                if viewModel.isScanning {
                    ProgressView().scaleEffect(0.8)
                } else {
                    HStack(spacing: 12) {
                        if let last = viewModel.lastRefreshed {
                            Text(last, style: .relative)
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        Button("刷新", systemImage: "arrow.clockwise") {
                            Task { await viewModel.refreshStorageInfo(force: true) }
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
                    statRow(label: "Other", value: FileSizeFormatter.string(from: max(0, info.usedBytes - known)), color: .textSecondary)
                }
            }
            .padding()
            .glassPanel(cornerRadius: 12)
        }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .rounded).monospacedDigit())
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Quick actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title2.bold())

            HStack(spacing: 16) {
                quickActionButton(title: "Smart Scan", subtitle: "扫描全部可清理项", icon: "sparkle.magnifyingglass", color: .appAccent) {
                    withAnimation { showSmartScan = true }
                    await cleanupVM.startScan()
                }
                quickActionButton(title: "Deep Clean", subtitle: "系统数据与开发缓存", icon: "trash.circle", color: .orange) {
                    appVM.selectedSidebarItem = .deepCleanup
                }
                quickActionButton(title: "Empty Trash", subtitle: "清空废纸篓", icon: "trash", color: .red) {
                    appVM.selectedSidebarItem = .trash
                }
                quickActionButton(title: "Analyze", subtitle: "磁盘占用明细", icon: "chart.pie", color: .purple) {
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
            .glassPanel(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent cleanup

    private var recentCleanupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Cleanup")
                    .font(.title2.bold())
                Spacer()
                Text("累计释放 \(FileSizeFormatter.string(from: cleanupHistory.totalFreedBytes))")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(cleanupHistory.records.prefix(5)) { record in
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.appAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.callout)
                                .foregroundColor(.textPrimary)
                            Text(record.categoryNames.joined(separator: "、"))
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if record.failedItems > 0 {
                            Text("\(record.failedItems) 项未完成")
                                .font(.caption)
                                .foregroundColor(.riskCaution)
                        }
                        FileSizeText(bytes: record.freedBytes, font: .callout.monospacedDigit(), color: .riskSafe)
                    }
                    .padding(.vertical, 8)
                    if record.id != cleanupHistory.records.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .glassPanel(cornerRadius: 12)
        }
    }

    // MARK: - Explore

    private var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore Tools")
                .font(.title2.bold())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                ForEach(SidebarItem.allCases.filter { $0 != .dashboard }) { item in
                    Button {
                        appVM.selectedSidebarItem = item
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: item.iconName)
                                .font(.title2)
                                .foregroundColor(.appAccent)
                            Text(item.displayName)
                                .font(.headline)
                                .foregroundColor(.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .glassPanel(cornerRadius: 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Smart scan

    @ViewBuilder
    private var smartScanSection: some View {
        switch cleanupVM.phase {
        case .idle, .scanning:
            scanningProgress
        case .results:
            scanResultsView
        case .cleaning(let progress):
            CleanupProgressView(progress: progress, onCancel: { cleanupVM.cancelCleanup() })
        case .complete(let summary):
            CleanupResultsView(summary: summary) {
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
                Button("重试") { cleanupVM.reset() }
            }
            .padding()
        }
    }

    private var scanningProgress: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("正在扫描…")
                .font(.title3.bold())
            Button("取消") {
                cleanupVM.cancelScan()
                withAnimation { showSmartScan = false }
            }
            .glassButton()
        }
        .padding(40)
        .glassPanel(cornerRadius: 16)
    }

    private var scanResultsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Smart Scan 结果")
                    .font(.title2.bold())
                Spacer()
                Text("\(cleanupVM.scanItems.count) 项 · \(FileSizeFormatter.string(from: cleanupVM.totalBytes))")
                    .font(.title3.bold())
                    .foregroundColor(.appAccent)
            }

            ForEach(cleanupVM.sortedScanItems.prefix(20)) { item in
                ScanItemRow(
                    item: item,
                    isSelected: cleanupVM.selectedItems.contains(item.id),
                    onToggle: { cleanupVM.toggleItem(item.id) }
                )
                Divider()
            }

            if cleanupVM.scanItems.count > 20 {
                Text("仅显示前 20 项，完整列表请在「Cache Cleanup」中查看")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            HStack(spacing: 12) {
                Button("查看全部") {
                    appVM.selectedSidebarItem = .cacheCleanup
                    withAnimation { showSmartScan = false }
                }
                .glassButton()

                Button {
                    if confirmBeforeClean { showCleanConfirm = true } else { Task { await cleanupVM.startCleanup() } }
                } label: {
                    Label("清理选中项", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .glassProminentButton()
                .controlSize(.large)
                .disabled(cleanupVM.selectedItems.isEmpty)

                Button("返回") {
                    withAnimation { showSmartScan = false }
                    cleanupVM.reset()
                }
                .glassButton()
            }
        }
        .padding()
        .glassPanel(cornerRadius: 16)
    }
}