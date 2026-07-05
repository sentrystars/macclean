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
                    Text("System data, macOS caches, Xcode artifacts, and VM images")
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

                if !viewModel.deepItems.isEmpty {
                    itemsList
                }

                if !viewModel.results.isEmpty {
                    resultsSection
                }

                if let err = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.riskCaution)
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    .background(Color.riskCaution.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private var startScanButton: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.appAccent)
            Text("Ready to Scan")
                .font(.title3.bold())
            Text("Scan system data, macOS caches, app containers, and development artifacts")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        Button(action: { Task { await viewModel.scan() } }) {
            Label("Scan All", systemImage: "magnifyingglass")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        }
        .padding(40)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .appShadow, radius: 4)
    }

    private var scanningSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning for deep cleanup items...")
                .foregroundColor(.textSecondary)
            Button("Cancel", role: .cancel) { viewModel.cancel() }
                .buttonStyle(.bordered)
        }
        .padding(40)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var itemsList: some View {
        VStack(spacing: 16) {
            // Summary and actions bar
            HStack {
                let totalSize = viewModel.deepItems.reduce(0) { $0 + $1.sizeBytes }
                let selectedSize = viewModel.deepItems.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.deepItems.count) items found")
                        .font(.headline)
                    Text("\(FileSizeFormatter.string(from: totalSize)) total — \(FileSizeFormatter.string(from: selectedSize)) selected")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Spacer()

                Button("Scan All", systemImage: "arrow.clockwise") {
                    Task { await viewModel.scan() }
                }
                .buttonStyle(.borderless)

                Button("Select All") {
                    for idx in viewModel.deepItems.indices { viewModel.deepItems[idx].isSelected = true }
                }
                .buttonStyle(.borderless)

                Button("Deselect All") {
                    for idx in viewModel.deepItems.indices { viewModel.deepItems[idx].isSelected = false }
                }
                .buttonStyle(.borderless)

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

            // Group items by storage bucket
            let groups = ["System Data", "macOS", "Application Caches"]
            ForEach(groups, id: \.self) { groupName in
                let groupItems = viewModel.deepItems.filter { $0.category.group == groupName }
                if !groupItems.isEmpty {
                    let grouped = Dictionary(grouping: groupItems) { $0.category }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(groupName)
                            .font(.title3.bold())
                            .foregroundColor(.appAccent)
                            .padding(.top, 4)

                        ForEach(grouped.keys.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { category in
                            deepCategorySection(category, items: grouped[category]!)
                        }
                    }
                }
            }
        }
    }

    private func deepCategorySection(_ category: CleanupCategory, items: [ScanItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.iconName)
                    .foregroundColor(category.color)
                Text(category.displayName)
                    .font(.headline)
                Spacer()
                let total = items.reduce(0) { $0 + $1.sizeBytes }
                Text(FileSizeFormatter.string(from: total))
                    .font(.subheadline.bold())
                    .foregroundColor(.appAccent)
            }

            ForEach(items) { item in
                HStack {
                    Button(action: { viewModel.toggleItem(item.id) }) {
                        HStack(spacing: 10) {
                            Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                .foregroundColor(item.isSelected ? .appAccent : .textSecondary)
                                .font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.subcategory ?? item.url.lastPathComponent)
                                    .font(.body)
                                    .foregroundColor(.textPrimary)
                                if let modified = item.lastModifiedFormatted {
                                    Text(modified)
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    } label: {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.appAccent)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")

                    StatusIcon(riskLevel: category.riskLevel)
                        .font(.caption)

                    Text(item.sizeFormatted)
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundColor(.textSecondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.leading, 12)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

            Button(action: { viewModel.results = []; viewModel.error = nil }) {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.riskSafe.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
