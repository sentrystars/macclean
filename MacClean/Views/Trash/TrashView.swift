import SwiftUI

struct TrashView: View {
    @State private var viewModel = TrashViewModel()
    @State private var showSecureEmptyConfirm = false
    @State private var showEmptyConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Trash Manager")
                        .font(.largeTitle.bold())
                    if viewModel.trashSize > 0 {
                        Text("\(FileSizeFormatter.string(from: viewModel.trashSize)) — \(viewModel.trashItems.count) items")
                            .foregroundColor(.textSecondary)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.riskSafe)
                            Text("Trash is empty")
                        }
                        .foregroundColor(.textSecondary)
                    }
                }

                if viewModel.trashSize > 0 {
                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: { showEmptyConfirm = true }) {
                            Label("Empty Trash", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)

                        Button(action: { showSecureEmptyConfirm = true }) {
                            Label("Secure Empty", systemImage: "lock.shield")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.large)
                    }

                    // Items list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contents")
                            .font(.title2.bold())

                        ForEach(viewModel.trashItems.prefix(30)) { item in
                            HStack {
                                Image(systemName: item.isDirectory ? "folder" : "doc")
                                    .foregroundColor(item.isDirectory ? .appAccent : .textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.subcategory ?? item.url.lastPathComponent)
                                        .lineLimit(1)
                                        .font(.body)
                                    if let modified = item.lastModifiedFormatted {
                                        Text(modified)
                                            .font(.caption)
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                Spacer()

                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                } label: {
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.appAccent)
                                }
                                .buttonStyle(.plain)
                                .help("Reveal in Finder")

                                FileSizeText(bytes: item.sizeBytes, font: .caption.monospacedDigit(), color: .textSecondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.horizontal)
                        }

                        if viewModel.trashItems.count > 30 {
                            Text("...and \(viewModel.trashItems.count - 30) more items")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if viewModel.isEmptying {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Emptying trash...")
                            .foregroundColor(.textSecondary)
                    }
                    .padding(40)
                }

                if let result = viewModel.result {
                    resultView(result)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task { await viewModel.refresh() }
        .alert("Empty Trash", isPresented: $showEmptyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Empty", role: .destructive) {
                self.emptyTrash()
            }
        } message: {
            Text("Are you sure you want to empty the trash? This action cannot be undone.")
        }
        .alert("Secure Empty Trash", isPresented: $showSecureEmptyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Secure Empty", role: .destructive) {
                self.secureEmptyTrash()
            }
        } message: {
            Text("This will overwrite the deleted files with random data, making recovery impossible. This may take some time.")
        }
    }

    private func emptyTrash() {
        Task { @MainActor in
            await viewModel.emptyTrash()
        }
    }

    private func secureEmptyTrash() {
        Task { @MainActor in
            await viewModel.secureEmptyTrash()
        }
    }

    private func resultView(_ result: CleanupResult) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.riskSafe)
            Text("Freed \(result.bytesFreedFormatted) (\(result.itemsRemoved) items)")
                .foregroundColor(.textSecondary)
        }
        .padding()
        .background(Color.riskSafe.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
