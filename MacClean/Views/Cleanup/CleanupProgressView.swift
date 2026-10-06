import SwiftUI

struct CleanupProgressView: View {
    let progress: CleanProgress
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trash.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("正在清理…")
                    .font(.title2.bold())
                Text(progress.phase)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            AnimatedProgressBar(value: progress.fractionCompleted, color: .appAccent)
                .frame(width: 300)

            VStack(spacing: 4) {
                Text("\(progress.itemsCleaned) / \(progress.totalItems) 项")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Text("已释放 \(FileSizeFormatter.string(from: progress.bytesFreed))")
                    .font(.caption)
                    .foregroundColor(.riskSafe)
                if !progress.failures.isEmpty {
                    Text("\(progress.failures.count) 项未处理")
                        .font(.caption)
                        .foregroundColor(.riskCaution)
                }
            }

            if !progress.currentItem.isEmpty {
                Text(progress.currentItem)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let onCancel {
                Button("取消", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .appShadow, radius: 4)
    }
}
