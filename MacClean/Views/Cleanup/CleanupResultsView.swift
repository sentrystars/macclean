import SwiftUI

struct CleanupResultsView: View {
    let summary: CleanupSummary
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: summary.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(summary.succeeded ? .riskSafe : .riskCaution)

            VStack(spacing: 4) {
                Text(summary.succeeded ? "清理完成" : "清理完成（部分项目未处理）")
                    .font(.title.bold())
                Text("本次释放：\(FileSizeFormatter.string(from: summary.freedBytes))，删除 \(summary.removedItems) 项，耗时 \(String(format: "%.1f", summary.duration)) 秒")
                    .font(.callout)
                    .foregroundColor(.textSecondary)
            }

            if !summary.results.isEmpty {
                VStack(spacing: 10) {
                    Text("分类明细")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(summary.results) { result in
                        HStack {
                            Image(systemName: result.category.iconName)
                                .foregroundColor(result.category.color)
                                .frame(width: 20)
                            Text(result.category.displayName)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text(result.bytesFreedFormatted)
                                .font(.system(.body, design: .rounded).monospacedDigit())
                                .foregroundColor(.riskSafe)
                            Text("(\(result.itemsRemoved) 项)")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            FailureListView(failures: summary.failures, title: "未删除的项目")

            Button(action: onDismiss) {
                Label("返回", systemImage: "arrow.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(24)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
