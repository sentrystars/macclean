import SwiftUI

struct DeepCleanView: View {
    @State private var viewModel = DeepCleanViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.riskCaution)
                    Text("Deep Cleanup")
                        .font(.largeTitle.bold())
                    Text("Target large, safe-to-delete files and caches")
                        .foregroundColor(.textSecondary)
                }

                // Warning banner
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.riskCaution)
                    Text("These items are generally safe to delete, but some may require app restarts. Review before cleaning.")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.riskCaution.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if viewModel.deepItems.isEmpty && !viewModel.isScanning {
                    startScanButton
                }

                if viewModel.isScanning {
                    scanningSection
                }

                // Items list
                if !viewModel.deepItems.isEmpty {
                    itemsList
                }

                // Results
                if !viewModel.results.isEmpty {
                    resultsSection
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private var startScanButton: some View {
        Button(action: { Task { await viewModel.scan() } }) {
            Label("Scan for Deep Cleanup Items", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var scanningSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning for deep cleanup items...")
                .foregroundColor(.textSecondary)
        }
        .padding(40)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var itemsList: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Found \(viewModel.deepItems.count) items")
                    .font(.headline)
                Spacer()
                Button(action: { Task { await viewModel.cleanSelected() } }) {
                    Label("Clean Selected", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(viewModel.isCleaning || viewModel.deepItems.filter(\.isSelected).isEmpty)
            }

            if viewModel.isCleaning {
                ProgressView()
                    .scaleEffect(0.8)
            }

            ForEach(viewModel.deepItems) { item in
                DangerItemCard(item: item) {
                    viewModel.toggleItem(item.id)
                }
            }
        }
    }

    private var resultsSection: some View {
        VStack(spacing: 12) {
            Text("Cleanup Results")
                .font(.headline)

            ForEach(viewModel.results) { result in
                HStack {
                    Image(systemName: result.category.iconName)
                        .foregroundColor(result.category.color)
                    Text(result.category.displayName)
                    Spacer()
                    Text(result.bytesFreedFormatted)
                        .foregroundColor(.riskSafe)
                        .monospacedDigit()
                }
                .padding()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.riskSafe.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Danger Item Card
struct DangerItemCard: View {
    let item: ScanItem
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { item.isSelected },
                set: { _ in onToggle() }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: item.category.iconName)
                            .foregroundColor(item.category.color)
                        Text(item.subcategory ?? item.url.lastPathComponent)
                            .font(.body)
                    }
                    Text(item.category.description)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    if let modified = item.lastModifiedFormatted {
                        Text("Last modified: \(modified)")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusIcon(riskLevel: item.category.riskLevel)
                FileSizeText(bytes: item.sizeBytes, font: .caption.monospacedDigit(), color: .textSecondary)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 2)
    }
}
