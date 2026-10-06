import SwiftUI

struct SimulatorRuntimeView: View {
    @State private var viewModel = SimulatorViewModel()
    @State private var pendingDelete: SimulatorRuntime?
    @State private var showDeleteConfirm = false
    @State private var showBulkConfirm = false
    @State private var bulkDays = 90

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                InfoBanner(
                    style: .warning,
                    message: "删除模拟器运行时会移除对应系统版本的模拟器能力（通常每个 5～17 GB）。Xcode 在需要时会重新下载。正在使用中的设备会先被关闭。"
                )

                if !viewModel.hasXcode {
                    InfoBanner(
                        style: .error,
                        message: "未检测到完整安装的 Xcode，模拟器功能不可用。"
                    )
                }

                if viewModel.isScanning {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("正在读取运行时…").font(.caption).foregroundColor(.textSecondary)
                    }
                }

                if viewModel.hasXcode && !viewModel.sortedRuntimes.isEmpty {
                    bulkActions
                    runtimeList
                }

                if viewModel.hasXcode {
                    deviceSection
                }

                if let message = viewModel.message {
                    InfoBanner(style: .success, message: message)
                }
                if let error = viewModel.error {
                    InfoBanner(style: .error, message: error)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appWindowBackground()
        .task { await viewModel.refresh() }
        .alert("删除运行时", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("删除", role: .destructive) {
                if let runtime = pendingDelete {
                    Task { await viewModel.delete(runtime) }
                }
                pendingDelete = nil
            }
        } message: {
            if let runtime = pendingDelete {
                Text("将删除「\(runtime.displayName)」，释放约 \(runtime.sizeFormatted)。删除后无法运行该版本的模拟器，需要时 Xcode 会重新下载。")
            }
        }
        .alert("批量清理运行时", isPresented: $showBulkConfirm) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) {
                Task { await viewModel.deleteNotUsed(days: bulkDays) }
            }
        } message: {
            Text("将删除超过 \(bulkDays) 天未使用过的模拟器运行时。")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Simulators")
                    .font(.largeTitle.bold())
                Text("模拟器运行时占用 \(FileSizeFormatter.string(from: viewModel.totalBytes))")
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .glassButton()
            .disabled(viewModel.isScanning)
        }
    }

    private var bulkActions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.deleteUnusableOrOutdated() }
            } label: {
                Label("清理不可用/过期", systemImage: "trash.slash")
            }
            .glassButton()
            .disabled(viewModel.isBulkRunning)

            Stepper("未使用超过 \(bulkDays) 天", value: $bulkDays, in: 30...730, step: 30)
                .frame(width: 190)

            Button {
                showBulkConfirm = true
            } label: {
                Label("按时间清理", systemImage: "clock.badge.xmark")
            }
            .glassButton()
            .disabled(viewModel.isBulkRunning)

            if viewModel.isBulkRunning {
                ProgressView().scaleEffect(0.7)
            }
            Spacer()
        }
    }

    private var runtimeList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.sortedRuntimes) { runtime in
                runtimeRow(runtime)
            }
        }
    }

    private func runtimeRow(_ runtime: SimulatorRuntime) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: runtime.iconName)
                    .font(.title3)
                    .foregroundColor(.appAccent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(runtime.displayName)
                        .font(.callout.bold())
                        .foregroundColor(.textPrimary)
                    HStack(spacing: 6) {
                        Text(runtime.isReady ? "就绪" : runtime.state)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background((runtime.isReady ? Color.riskSafe : Color.riskCaution).opacity(0.14))
                            .clipShape(Capsule())
                        if let lastUsed = runtime.lastUsedFormatted {
                            Text("最近使用：\(lastUsed)")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }
                        if !runtime.isDeletable {
                            Text("不可删除")
                                .font(.caption2)
                                .foregroundColor(.riskWarning)
                        }
                    }
                }

                Spacer()

                Text(runtime.sizeFormatted)
                    .font(.system(.callout, design: .rounded).monospacedDigit())
                    .foregroundColor(.textPrimary)
                    .frame(width: 90, alignment: .trailing)

                Button {
                    pendingDelete = runtime
                    showDeleteConfirm = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .glassButton()
                .controlSize(.small)
                .disabled(!runtime.isDeletable || viewModel.busyRuntimeID != nil)

                if viewModel.busyRuntimeID == runtime.identifier {
                    ProgressView().scaleEffect(0.6)
                }

                Button {
                    viewModel.reveal(runtime)
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.appAccent)
                }
                .buttonStyle(.plain)
                .help("在 Finder 中显示")
                .disabled(runtime.mountPath == nil)
            }

            if let path = runtime.mountPath {
                Text(path)
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 12)
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("模拟器设备")
                .font(.title3.bold())
            HStack(spacing: 24) {
                statBlock(title: "设备总数", value: "\(viewModel.devices.total)")
                statBlock(title: "不可用", value: "\(viewModel.devices.unavailable)")
                statBlock(title: "运行中", value: "\(viewModel.devices.booted)")
                Spacer()
                Button {
                    Task { await viewModel.deleteUnavailableDevices() }
                } label: {
                    Label("删除不可用设备", systemImage: "iphone.slash")
                }
                .glassButton()
                .disabled(viewModel.isBulkRunning || viewModel.devices.unavailable == 0)
            }
        }
        .padding()
        .glassPanel(cornerRadius: 14)
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.textPrimary)
        }
    }
}
