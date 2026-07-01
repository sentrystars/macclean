import SwiftUI

struct CleanupProgressView: View {
    let progress: CleanProgress

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trash.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("Cleaning...")
                    .font(.title2.bold())
                Text(progress.phase)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            AnimatedProgressBar(
                value: progress.fractionCompleted,
                color: .appAccent
            )
            .frame(width: 300)

            VStack(spacing: 4) {
                Text("\(progress.itemsCleaned) of \(progress.totalItems) items")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Text("\(FileSizeFormatter.string(from: progress.bytesFreed)) freed")
                    .font(.caption)
                    .foregroundColor(.riskSafe)
            }

            if progress.fractionCompleted > 0 {
                Text(progress.currentItem)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(40)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}
