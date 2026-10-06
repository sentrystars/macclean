import SwiftUI

struct DeepCleanView: View {
    @State private var viewModel = DeepCleanViewModel()
    @State private var showCleanConfirm = false
    @State private var hasFullDiskAccess = true
    @AppStorage(SettingsKey.confirmBeforeClean) private var confirmBeforeClean = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if !hasFullDiskAccess {
                    FullDiskAccessBanner()
                }

                InfoBanner(
                    style: .warning,
                    message: "以下项目多为可再生数据，但删除后部分应用需要重启或重新登录。需要管理员权限的项目会集中弹一次授权。"
                )

                if viewModel.deepItems.isEmpty && !viewModel.isScanning {
                    startScanButton
                }

                if viewModel.isScanning {
                    scanningSection
                }

                if !viewModel.deepItems.isEmpty {
                    itemsList
                }

                if let summary = viewModel.summary {
                    CleanupResultsView(summary: summary) {
                        viewModel.summary = nil
                    }
                }

                maintenanceSection

                if let error = viewModel.error {
                    InfoBanner(style: .error, message: error)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appWindowBackground()
        .task {
            hasFullDiskAccess = await Task.detached(priority: .utility) {
                MaintenanceService().hasFullDiskAccess()
            }.value
        }
        .alert("确认清理", isPresented: $showCleanConfirm) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) {
                Task { await viewModel.cleanSelected() }
            }
        } message: {
            Text("将永久删除 \(viewModel.selectedCount) 个项目，共 \(FileSizeFormatter.string(from: viewModel.selectedBytes))。此操作不可撤销。")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.riskCaution)
            Text("Deep Cleanup")
                .font(.largeTitle.bold())
            Text("系统数据、macOS 缓存、开发产物与 VM 镜像")
                .foregroundColor(.textSecondary)
        }
    }

    private var startScanButton: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.appAccent)
            Text("准备就绪")
                .font(.title3.bold())
            Text("扫描系统数据、macOS 缓存、应用容器与开发产物")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.scan() }
            } label: {
                Label("开始扫描", systemImage: "magnifyingglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .glassProminentButton()
            .controlSize(.large)
        }
        .padding(40)
        .glassPanel(cornerRadius: 16)
    }

    private var scanningSection: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("正在扫描深度清理项目…")
                .foregroundColor(.textSecondary)
            Button("取消", role: .cancel) { viewModel.cancel() }
                .glassButton()
        }
        .padding(40)
        .glassPanel(cornerRadius: 16)
    }

    private var itemsList: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.deepItems.count) 个项目")
                        .font(.headline)
                    Text("合计 \(FileSizeFormatter.string(from: viewModel.totalBytes))，已选 \(FileSizeFormatter.string(from: viewModel.selectedBytes))")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                Button("重新扫描", systemImage: "arrow.clockwise") {
                    Task { await viewModel.scan() }
                }
                .buttonStyle(.borderless)
                Button("全选") { viewModel.selectAll() }
                    .buttonStyle(.borderless)
                Button("全不选") { viewModel.deselectAll() }
                    .buttonStyle(.borderless)
                Button {
                    if confirmBeforeClean { showCleanConfirm = true } else { Task { await viewModel.cleanSelected() } }
                } label: {
                    Label("清理选中项", systemImage: "trash")
                }
                .glassProminentButton()
                .tint(.orange)
                .disabled(viewModel.isCleaning || viewModel.selectedCount == 0)
            }

            if viewModel.isCleaning {
                ProgressView().scaleEffect(0.8)
            }

            ForEach(["System Data", "macOS", "Application Caches", "Developer"], id: \.self) { groupName in
                let groupItems = viewModel.deepItems.filter { $0.category.group == groupName }
                if !groupItems.isEmpty {
                    let grouped = Dictionary(grouping: groupItems) { $0.category }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(groupName)
                            .font(.title3.bold())
                            .foregroundColor(.appAccent)

                        ForEach(grouped.keys.sorted { $0.displayName < $1.displayName }, id: \.self) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: category.iconName)
                                        .foregroundColor(category.color)
                                    Text(category.displayName)
                                        .font(.headline)
                                    Spacer()
                                    Text(FileSizeFormatter.string(from: grouped[category]!.reduce(0) { $0 + $1.sizeBytes }))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.appAccent)
                                }
                                ForEach(grouped[category]!) { item in
                                    ScanItemRow(
                                        item: item,
                                        isSelected: item.isSelected,
                                        onToggle: { viewModel.toggleItem(item.id) }
                                    )
                                }
                            }
                            .padding()
                            .glassPanel(cornerRadius: 12)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 系统维护

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统维护")
                .font(.title2.bold())
            Text("不依赖逐项勾选的整体操作")
                .font(.caption)
                .foregroundColor(.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
                ForEach(MaintenanceKind.allCases) { kind in
                    maintenanceCard(kind)
                }
            }

            ForEach(viewModel.maintenanceResults.prefix(5)) { result in
                MaintenanceResultRow(result: result)
            }
        }
    }

    private func maintenanceCard(_ kind: MaintenanceKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: kind.iconName)
                    .foregroundColor(kind.isDestructive ? .riskCaution : .appAccent)
                Text(kind.title)
                    .font(.headline)
                Spacer()
                if kind.requiresPrivilege {
                    Image(systemName: "lock.shield")
                        .font(.caption)
                        .foregroundColor(.riskCaution)
                }
            }
            Text(kind.detail)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.runMaintenance(kind) }
            } label: {
                if viewModel.runningMaintenance == kind {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6)
                        Text("执行中…")
                    }
                } else {
                    Text("执行")
                }
            }
            .glassButton()
            .disabled(viewModel.runningMaintenance != nil)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 12)
    }
}