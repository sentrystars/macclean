import SwiftUI

struct CleanupCategoriesView: View {
    @State private var viewModel = CleanupViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                switch viewModel.phase {
                case .idle:
                    categoriesGrid
                case .scanning(let progress):
                    scanningView(progress)
                case .results(let items):
                    resultsView(items)
                case .cleaning(let progress):
                    CleanupProgressView(progress: progress)
                case .complete(let results):
                    CleanupResultsView(results: results) {
                        viewModel.reset()
                    }
                case .error(let message):
                    errorView(message)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cache Cleanup")
                    .font(.largeTitle.bold())
                Text("Select categories to scan and clean")
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if case .idle = viewModel.phase {
                Button(action: { Task { await viewModel.startScan() } }) {
                    Label("Start Scan", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var categoriesGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
            ForEach(CleanupCategory.allCases, id: \.self) { category in
                CategoryCardView(category: category, sizeBytes: 0)
            }
        }
    }

    private func scanningView(_ progress: ScanProgress) -> some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Scanning your Mac...")
                    .font(.title2.bold())
                Text(progress.phase)
                    .foregroundColor(.textSecondary)
            }

            AnimatedProgressBar(
                value: progress.fractionCompleted,
                color: .appAccent
            )
            .frame(width: 300)

            VStack(spacing: 4) {
                Text("\(progress.filesScanned) files examined")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Text("\(FileSizeFormatter.string(from: progress.bytesFound)) found")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(40)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func resultsView(_ items: [ScanItem]) -> some View {
        VStack(spacing: 16) {
            // Summary bar
            HStack {
                let totalSize = items.reduce(0) { $0 + $1.sizeBytes }
                let selectedSize = items.filter { viewModel.selectedItems.contains($0.id) }
                    .reduce(0) { $0 + $1.sizeBytes }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Found \(items.count) items")
                        .font(.headline)
                    Text("\(FileSizeFormatter.string(from: totalSize)) total — \(FileSizeFormatter.string(from: selectedSize)) selected")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Spacer()

                Button("Select All") {
                    viewModel.selectedItems = Set(items.map(\.id))
                }
                .buttonStyle(.borderless)

                Button(action: { Task { await viewModel.startCleanup() } }) {
                    Label("Clean Selected", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedItems.isEmpty)
            }

            // Items list grouped by category
            let grouped = Dictionary(grouping: items) { $0.category }
            ForEach(grouped.keys.sorted { $0.displayName < $1.displayName }, id: \.self) { category in
                categorySection(category, items: grouped[category]!)
            }
        }
    }

    private func categorySection(_ category: CleanupCategory, items: [ScanItem]) -> some View {
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
                    Toggle(isOn: Binding(
                        get: { viewModel.selectedItems.contains(item.id) },
                        set: { _ in viewModel.toggleItem(item.id) }
                    )) {
                        VStack(alignment: .leading) {
                            Text(item.subcategory ?? item.url.lastPathComponent)
                                .font(.body)
                            if let modified = item.lastModifiedFormatted {
                                Text(modified)
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)

                    Spacer()

                    StatusIcon(riskLevel: category.riskLevel)
                        .font(.caption)

                    Text(item.sizeFormatted)
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundColor(.textSecondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.leading, 20)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.riskCaution)
            Text("Error")
                .font(.title2.bold())
            Text(message)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
