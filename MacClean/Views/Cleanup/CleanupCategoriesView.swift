import SwiftUI

struct CleanupCategoriesView: View {
    @State private var viewModel = CleanupViewModel()
    @State private var showCleanConfirm = false
    @AppStorage(SettingsKey.confirmBeforeClean) private var confirmBeforeClean = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                content
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appWindowBackground()
        .alert("确认清理", isPresented: $showCleanConfirm) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) {
                Task { await viewModel.startCleanup() }
            }
        } message: {
            Text("将永久删除 \(viewModel.selectedCount) 个项目，共 \(FileSizeFormatter.string(from: viewModel.selectedBytes))。此操作不可撤销。")
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cache Cleanup")
                    .font(.largeTitle.bold())
                Text("扫描并按应用粒度清理缓存、日志与系统数据")
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if case .idle = viewModel.phase {
                Button {
                    Task { await viewModel.startScan() }
                } label: {
                    Label("开始扫描", systemImage: "magnifyingglass")
                }
                .glassProminentButton()
                .controlSize(.large)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            categoriesGrid
        case .scanning(let progress):
            scanningView(progress)
        case .results:
            resultsView
        case .cleaning(let progress):
            CleanupProgressView(progress: progress, onCancel: { viewModel.cancelCleanup() })
        case .complete(let summary):
            CleanupResultsView(summary: summary) { viewModel.reset() }
        case .error(let message):
            errorView(message)
        }
    }

    private var categoriesGrid: some View {
        VStack(spacing: 20) {
            InfoBanner(
                style: .info,
                message: "清理前会逐项校验安全策略：浏览器配置、钥匙串、应用包等用户数据不会被删除；需要管理员权限的项目会集中弹一次授权。"
            )
            ForEach(["Application Caches", "Developer", "System Data", "macOS"], id: \.self) { groupName in
                let categories = CleanupCategory.allCases.filter { $0.group == groupName }
                if !categories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(groupName)
                            .font(.headline)
                            .foregroundColor(.textSecondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                            ForEach(categories) { category in
                                CategoryCardView(category: category, sizeBytes: 0) {
                                    Task { await viewModel.startScan() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func scanningView(_ progress: ScanProgress) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            VStack(spacing: 8) {
                Text("正在扫描…")
                    .font(.title2.bold())
                Text(progress.phase)
                    .foregroundColor(.textSecondary)
            }
            AnimatedProgressBar(value: progress.fractionCompleted, color: .appAccent)
                .frame(width: 320)
            VStack(spacing: 4) {
                Text("已发现 \(progress.filesScanned) 项")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Text("合计 \(FileSizeFormatter.string(from: progress.bytesFound))")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Text("\(progress.categoriesCompleted) / \(progress.totalCategories) 个分类完成")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
            Button("取消", role: .cancel) { viewModel.cancelScan() }
                .glassButton()
        }
        .padding(40)
        .glassPanel(cornerRadius: 16)
    }

    private var resultsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("发现 \(viewModel.scanItems.count) 项")
                        .font(.headline)
                    Text("合计 \(FileSizeFormatter.string(from: viewModel.totalBytes))，已选 \(FileSizeFormatter.string(from: viewModel.selectedBytes))")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Spacer()

                Picker("排序", selection: Bindable(viewModel).sortBy) {
                    ForEach(CleanupViewModel.SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                Button("全选安全项") { viewModel.selectSafeOnly() }
                    .buttonStyle(.borderless)
                Button("全选") { viewModel.selectAll() }
                    .buttonStyle(.borderless)
                Button("全不选") { viewModel.selectNone() }
                    .buttonStyle(.borderless)

                Button {
                    if confirmBeforeClean { showCleanConfirm = true } else { Task { await viewModel.startCleanup() } }
                } label: {
                    Label("清理选中项", systemImage: "trash")
                }
                .glassProminentButton()
                .disabled(viewModel.selectedItems.isEmpty)
            }

            if viewModel.scanItems.isEmpty {
                InfoBanner(style: .success, message: "没有发现可清理的项目，你的 Mac 很干净。")
            }

            ForEach(viewModel.groupedItems(), id: \.group) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.group)
                        .font(.title3.bold())
                        .foregroundColor(.appAccent)

                    ForEach(section.categories, id: \.category) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: entry.category.iconName)
                                    .foregroundColor(entry.category.color)
                                Text(entry.category.displayName)
                                    .font(.headline)
                                Spacer()
                                Text(FileSizeFormatter.string(from: entry.items.reduce(0) { $0 + $1.sizeBytes }))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.appAccent)
                            }

                            ForEach(entry.items) { item in
                                ScanItemRow(
                                    item: item,
                                    isSelected: viewModel.selectedItems.contains(item.id),
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

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.riskCaution)
            Text(message)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            Button("重试") { viewModel.reset() }
                .glassProminentButton()
        }
        .padding(40)
        .glassPanel(cornerRadius: 16)
    }
}