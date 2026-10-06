import SwiftUI

struct PrivacyCleanerView: View {
    @State private var viewModel = PrivacyViewModel()
    @State private var showConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                InfoBanner(
                    style: .warning,
                    message: "隐私数据清理不可逆地改变浏览器状态：Cookie 清理后需要重新登录，历史记录无法恢复。所有内容会先移入废纸篓，仍可从废纸篓恢复。"
                )

                ForEach(viewModel.groupedTargets, id: \.group) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.group)
                            .font(.title3.bold())
                            .foregroundColor(.appAccent)

                        VStack(spacing: 0) {
                            ForEach(section.items) { target in
                                targetRow(target)
                                if target.id != section.items.last?.id { Divider() }
                            }
                        }
                        .padding(.vertical, 4)
                        .glassPanel(cornerRadius: 12)
                    }
                }

                HStack {
                    Text("已选 \(viewModel.selected.count) 项 · \(FileSizeFormatter.string(from: viewModel.selectedBytes))")
                        .font(.callout)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Button("刷新大小") { Task { await viewModel.scanSizes() } }
                        .buttonStyle(.borderless)
                    Button {
                        showConfirm = true
                    } label: {
                        Label("清理所选", systemImage: "hand.raised")
                    }
                    .glassProminentButton()
                    .disabled(viewModel.selected.isEmpty || viewModel.isCleaning)
                }

                if let message = viewModel.lastMessage {
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
        .task { await viewModel.scanSizes() }
        .alert("确认隐私清理", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("移入废纸篓", role: .destructive) {
                Task { await viewModel.cleanSelected() }
            }
        } message: {
            Text("将清理 \(viewModel.selected.count) 项隐私数据，约 \(FileSizeFormatter.string(from: viewModel.selectedBytes))。")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Privacy")
                    .font(.largeTitle.bold())
                Text("按需清理浏览记录、Cookie 与最近使用项")
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if viewModel.isScanning {
                ProgressView().scaleEffect(0.8)
            }
        }
    }

    private func targetRow(_ target: PrivacyTarget) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { viewModel.isSelected(target.id) },
                set: { _ in viewModel.toggle(target.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(target.name)
                    .font(.callout)
                    .foregroundColor(.textPrimary)
                Text(target.detail)
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                if !target.requiredClosedBundleIDs.isEmpty {
                    Text("需要先退出对应浏览器")
                        .font(.caption2)
                        .foregroundColor(.riskCaution)
                }
            }
            Spacer()
            let size = viewModel.sizes[target.id] ?? 0
            if size > 0 {
                FileSizeText(bytes: size, font: .callout.monospacedDigit(), color: .textSecondary)
            } else {
                Text("无数据")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}