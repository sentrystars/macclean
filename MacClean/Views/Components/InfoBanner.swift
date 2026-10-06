import SwiftUI

/// 通用提示条（信息/警告/成功/错误）。
struct InfoBanner: View {
    enum Style {
        case info, warning, success, error

        var color: Color {
            switch self {
            case .info: return .appAccent
            case .warning: return .riskCaution
            case .success: return .riskSafe
            case .error: return .riskWarning
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.octagon.fill"
            }
        }
    }

    let style: Style
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: style.icon)
                .foregroundColor(style.color)
            Text(message)
                .font(.callout)
                .foregroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
                    .foregroundColor(.appAccent)
            }
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
                .help("不再提示")
            }
        }
        .padding(12)
        .background(style.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 清理失败/被拒条目的可展开列表。
struct FailureListView: View {
    let failures: [CleanupFailure]
    var title: String = "未完成的项目"
    @State private var expanded = false

    var body: some View {
        if !failures.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation { expanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.riskCaution)
                        Text("\(title)（\(failures.count)）")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(failures) { failure in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(failure.displayName)
                                    .font(.callout)
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1)
                                Text(failure.reason)
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                Text(failure.path)
                                    .font(.caption2)
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding()
            .background(Color.riskCaution.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// 完全磁盘访问授权提示。
struct FullDiskAccessBanner: View {
    @AppStorage(SettingsKey.hideFullDiskAccessWarning) private var hidden = false

    var body: some View {
        if !hidden {
            InfoBanner(
                style: .warning,
                message: "未获得「完全磁盘访问」权限，部分目录（邮件、Safari、其他应用容器等）无法扫描，空间统计会偏小。",
                actionTitle: "打开系统设置",
                action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                },
                onDismiss: { hidden = true }
            )
        }
    }
}

/// 维护动作的结果行。
struct MaintenanceResultRow: View {
    let result: MaintenanceResult

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(result.succeeded ? .riskSafe : .riskCaution)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.kind.title)
                    .font(.callout.bold())
                    .foregroundColor(.textPrimary)
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(3)
            }
            Spacer()
            if result.freedBytes > 0 {
                FileSizeText(bytes: result.freedBytes, font: .callout.monospacedDigit(), color: .riskSafe)
            }
        }
        .padding(10)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
