import SwiftUI

/// 扫描条目行：复选框 + 名称 + 风险提示 + 大小 + Finder 定位。
struct ScanItemRow: View {
    let item: ScanItem
    let isSelected: Bool
    var onToggle: () -> Void
    var showRisk: Bool = true
    var showCheckbox: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            if showCheckbox {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!item.isRemovable)
                .help(item.isRemovable ? "" : (item.notRemovableReason ?? "不可删除"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.callout)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    if let modified = item.lastModifiedFormatted {
                        Text(modified)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    if item.requiresPrivilege {
                        Label("需要管理员权限", systemImage: "lock.shield")
                            .font(.caption2)
                            .foregroundColor(.riskCaution)
                    }
                    if !item.isRemovable {
                        Text(item.notRemovableReason ?? "不可删除")
                            .font(.caption2)
                            .foregroundColor(.riskWarning)
                    }
                }
            }

            Spacer(minLength: 8)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.appAccent)
            }
            .buttonStyle(.plain)
            .help("在 Finder 中显示")

            if showRisk {
                StatusIcon(riskLevel: item.riskLevel)
                    .font(.caption)
            }

            Text(item.sizeFormatted)
                .font(.system(.callout, design: .rounded).monospacedDigit())
                .foregroundColor(.textSecondary)
                .frame(width: 84, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }
}
