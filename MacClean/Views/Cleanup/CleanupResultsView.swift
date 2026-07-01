import SwiftUI

struct CleanupResultsView: View {
    let results: [CleanupResult]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Success animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.riskSafe)

            VStack(spacing: 4) {
                Text("Cleanup Complete!")
                    .font(.largeTitle.bold())
                let total = results.reduce(0) { $0 + $1.bytesFreed }
                Text("Total space freed: \(FileSizeFormatter.string(from: total))")
                    .font(.title3)
                    .foregroundColor(.appAccent)
            }

            // Per-category breakdown
            VStack(spacing: 12) {
                Text("Breakdown")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(results) { result in
                    HStack {
                        Image(systemName: result.category.iconName)
                            .foregroundColor(result.category.color)
                            .frame(width: 20)
                        Text(result.category.displayName)
                        Spacer()
                        Text(result.bytesFreedFormatted)
                            .font(.system(.body, design: .rounded).monospacedDigit())
                            .foregroundColor(.riskSafe)
                        Text("(\(result.itemsRemoved) items)")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: onDismiss) {
                Label("Back to Categories", systemImage: "arrow.left")
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
