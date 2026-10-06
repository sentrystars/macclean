import SwiftUI

struct SystemDataView: View {
    @State private var viewModel = SystemDataViewModel()
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if viewModel.storageInfo != nil {
                    summarySection
                }

                InfoBanner(
                    style: .info,
                    message: "对应 macOS「存储空间」里说不清的 System Data。可清理项都是可再生缓存；系统管理项（诊断数据库、swap、临时目录）不建议手动删除。"
                )

                bucketList

                if viewModel.isScanning {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("正在统计…").font(.caption).foregroundColor(.textSecondary)
                    }
                }

                if let error = viewModel.error {
                    InfoBanner(style: .error, message: error)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appWindowBackground()
        .task { await viewModel.analyze() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Data")
                    .font(.largeTitle.bold())
                Text("系统数据占用分析")
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Button {
                Task { await viewModel.analyze() }
            } label: {
                Label("重新分析", systemImage: "arrow.clockwise")
            }
            .glassButton()
            .disabled(viewModel.isScanning)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已统计构成")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text(FileSizeFormatter.string(from: viewModel.totalBytes))
                        .font(.title.bold())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("可清理（可再生）")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text(FileSizeFormatter.string(from: viewModel.cleanableBytes))
                        .font(.title3.bold())
                        .foregroundColor(.riskSafe)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("需确认")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text(FileSizeFormatter.string(from: viewModel.reviewBytes))
                        .font(.title3.bold())
                        .foregroundColor(.riskCaution)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地快照")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text("\(viewModel.snapshotCount) 个")
                        .font(.title3.bold())
                }
                Spacer()
            }

            if let info = viewModel.storageInfo {
                let usedText = FileSizeFormatter.string(from: info.usedBytes)
                let totalText = FileSizeFormatter.string(from: info.totalBytes)
                let freeText = FileSizeFormatter.string(from: info.freeBytes)
                Text("磁盘：已用 \(usedText) / 共 \(totalText)，可用 \(freeText)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .glassPanel(cornerRadius: 14)
    }

    private var bucketList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.sortedBuckets) { bucket in
                bucketRow(bucket)
            }
        }
    }

    private func bucketRow(_ bucket: SystemDataBucket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon(for: bucket))
                    .foregroundColor(color(for: bucket))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bucket.title)
                        .font(.callout.bold())
                        .foregroundColor(.textPrimary)
                    Text(bucket.detail)
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Text(bucket.safety.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color(for: bucket).opacity(0.12))
                    .clipShape(Capsule())

                Text(FileSizeFormatter.string(from: bucket.sizeBytes))
                    .font(.system(.callout, design: .rounded).monospacedDigit())
                    .foregroundColor(.textPrimary)
                    .frame(width: 90, alignment: .trailing)

                if bucket.safety == .cleanable {
                    Button("去清理") {
                        appVM.selectedSidebarItem = .cacheCleanup
                    }
                    .glassButton()
                    .controlSize(.small)
                }

                Button {
                    if let first = bucket.paths.first { viewModel.reveal(first) }
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.appAccent)
                }
                .buttonStyle(.plain)
                .help("在 Finder 中显示")
            }

            if viewModel.totalBytes > 0 {
                ProgressView(value: Double(bucket.sizeBytes) / Double(max(viewModel.totalBytes, 1)))
                    .tint(color(for: bucket))
            }

            Text(bucket.paths.joined(separator: "    "))
                .font(.caption2)
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .glassPanel(cornerRadius: 12)
    }

    private func color(for bucket: SystemDataBucket) -> Color {
        switch bucket.safety {
        case .cleanable: return .riskSafe
        case .review: return .riskCaution
        case .systemManaged: return .textSecondary
        }
    }

    private func icon(for bucket: SystemDataBucket) -> String {
        switch bucket.id {
        case "sim-runtimes", "sim-caches", "user-developer": return "iphone"
        case "command-line-tools": return "terminal"
        case "npm", "pnpm": return "shippingbox"
        case "dot-cache", "other-dev": return "folder.badge.gearshape"
        case "rustup", "jvm": return "hammer"
        case "ai-tools", "ollama": return "sparkles"
        case "app-support", "containers", "system-support": return "square.grid.3x3"
        case "user-caches", "system-caches": return "externaldrive.fill"
        case "user-logs": return "doc.text"
        case "system-db": return "cylinder.split.1x2"
        case "vm": return "memorychip"
        case "var-folders": return "clock.arrow.circlepath"
        default: return "internaldrive"
        }
    }
}
