import SwiftUI

struct TrashView: View {
    @State private var viewModel = TrashViewModel()
    @State private var showEmptyConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if viewModel.trashSize > 0 {
                    HStack(spacing: 16) {
                        Button {
                            showEmptyConfirm = true
                        } label: {
                            Label("清空废纸篓", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .disabled(viewModel.isEmptying)

                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    contentsList
                }

                if viewModel.isEmptying {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text("正在清空废纸篓…")
                            .foregroundColor(.textSecondary)
                    }
                    .padding(40)
                }

                if let error = viewModel.error {
                    InfoBanner(style: .error, message: error)
                }

                if let result = viewModel.result {
                    InfoBanner(
                        style: result.errors.isEmpty ? .success : .warning,
                        message: "已释放 \(result.bytesFreedFormatted)，删除 \(result.itemsRemoved) 项"
                            + (result.errors.isEmpty ? "" : "，\(result.errors.count) 项未删除")
                    )
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task { await viewModel.refresh() }
        .alert("清空废纸篓", isPresented: $showEmptyConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                Task { await viewModel.emptyTrash() }
            }
        } message: {
            Text("将永久删除废纸篓中的全部内容，此操作无法撤销。")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "trash.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Trash Manager")
                .font(.largeTitle.bold())
            if viewModel.trashSize > 0 {
                Text("\(FileSizeFormatter.string(from: viewModel.trashSize)) · \(viewModel.trashItems.count) 项")
                    .foregroundColor(.textSecondary)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.riskSafe)
                    Text("废纸篓是空的")
                }
                .foregroundColor(.textSecondary)
            }
        }
    }

    private var contentsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内容")
                .font(.title2.bold())

            ForEach(viewModel.trashItems.prefix(50)) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.isDirectory ? "folder" : "doc")
                        .foregroundColor(item.isDirectory ? .appAccent : .textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let modified = item.lastModifiedFormatted {
                            Text(modified)
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    Spacer()
                    Button {
                        viewModel.reveal(item)
                    } label: {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.appAccent)
                    }
                    .buttonStyle(.plain)
                    .help("在 Finder 中显示")

                    FileSizeText(bytes: item.sizeBytes, font: .caption.monospacedDigit(), color: .textSecondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal)
            }

            if viewModel.trashItems.count > 50 {
                Text("…以及其余 \(viewModel.trashItems.count - 50) 项")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
