import SwiftUI

struct DuplicateFinderView: View {
    @State private var viewModel = DuplicateFinderViewModel()
    @State private var showRemoveConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                InfoBanner(
                    style: .info,
                    message: "只扫描下载、文档、桌面、影片、音乐、图片等标准文件夹；结果一律移入废纸篓，可随时恢复。"
                )

                if viewModel.isScanning {
                    scanningSection
                } else if !viewModel.groups.isEmpty {
                    summaryBar
                    groupsList
                } else if let message = viewModel.lastMessage {
                    InfoBanner(style: .success, message: message)
                }

                if let error = viewModel.error {
                    InfoBanner(style: .error, message: error)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .alert("确认清理重复文件", isPresented: $showRemoveConfirm) {
            Button("取消", role: .cancel) {}
            Button("移入废纸篓", role: .destructive) {
                Task { await viewModel.removeSelected() }
            }
        } message: {
            Text("将把 \(viewModel.selectedPaths.count) 个文件移入废纸篓，约 \(FileSizeFormatter.string(from: viewModel.selectedBytes))。")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duplicate Finder")
                    .font(.largeTitle.bold())
                Text("按内容哈希查找重复文件")
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Stepper("最小 \(viewModel.minimumSizeMB) MB", value: Bindable(viewModel).minimumSizeMB, in: 1...100)
                .frame(width: 150)
                .disabled(viewModel.isScanning)
            Button {
                Task { await viewModel.scan() }
            } label: {
                Label(viewModel.groups.isEmpty ? "开始查找" : "重新查找", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isScanning)
        }
    }

    private var scanningSection: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("正在扫描并计算哈希…")
                .foregroundColor(.textSecondary)
            Text("已发现 \(viewModel.groups.count) 组重复")
                .font(.caption)
                .foregroundColor(.textSecondary)
            Button("取消", role: .cancel) { viewModel.cancelScan() }
                .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var summaryBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.groups.count) 组重复 · \(viewModel.totalFiles) 个文件")
                    .font(.headline)
                Text("可释放约 \(FileSizeFormatter.string(from: viewModel.totalWasted))（已勾选 \(FileSizeFormatter.string(from: viewModel.selectedBytes))）")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Button("每组保留最早一份") { viewModel.autoSelectExtras() }
                .buttonStyle(.borderless)
            Button("全部取消勾选") { viewModel.clearSelection() }
                .buttonStyle(.borderless)
            Button {
                showRemoveConfirm = true
            } label: {
                Label("移入废纸篓", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedPaths.isEmpty)
        }
    }

    private var groupsList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(.appAccent)
                        Text("\(group.count) 个相同文件 · 每个 \(FileSizeFormatter.string(from: group.sizeBytes))")
                            .font(.headline)
                        Spacer()
                        Text("可释放 \(FileSizeFormatter.string(from: group.wastedBytes))")
                            .font(.caption)
                            .foregroundColor(.riskCaution)
                    }

                    ForEach(group.files) { file in
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { viewModel.isSelected(file.url.path) },
                                set: { _ in viewModel.toggle(file.url.path) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.displayName)
                                    .font(.callout)
                                    .lineLimit(1)
                                Text(file.url.deletingLastPathComponent().path)
                                    .font(.caption2)
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            if let modified = file.modifiedFormatted {
                                Text(modified)
                                    .font(.caption2)
                                    .foregroundColor(.textSecondary)
                            }
                            Button {
                                viewModel.reveal(file.url)
                            } label: {
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.appAccent)
                            }
                            .buttonStyle(.plain)
                            .help("在 Finder 中显示")
                        }
                        .padding(.leading, 4)
                    }
                }
                .padding()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
