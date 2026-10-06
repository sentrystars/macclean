import SwiftUI

struct UninstallerView: View {
    @State private var viewModel = UninstallerViewModel()
    @State private var pendingApp: InstalledApp?
    @State private var uninstallTarget: InstalledApp?
    @State private var showUninstallConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if viewModel.isScanning {
                    scanningSection
                } else if viewModel.apps.isEmpty {
                    emptySection
                } else {
                    listSection
                }

                if let result = viewModel.lastResult {
                    InfoBanner(
                        style: result.succeeded ? .success : .warning,
                        message: "已卸载「\(result.appName)」：移入废纸篓 \(result.movedToTrash.count) 项，释放约 \(FileSizeFormatter.string(from: result.freedBytes))"
                            + (result.failures.isEmpty ? "" : "，\(result.failures.count) 项未处理")
                    )
                }

                if let error = viewModel.error {
                    InfoBanner(style: .error, message: error)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .sheet(item: $pendingApp) { app in
            AssociatedFilesSheet(app: app, viewModel: viewModel)
        }
        .alert("确认卸载", isPresented: $showUninstallConfirm) {
            Button("取消", role: .cancel) { uninstallTarget = nil }
            Button("移到废纸篓", role: .destructive) {
                if let target = uninstallTarget {
                    Task { await viewModel.uninstall(target) }
                }
                uninstallTarget = nil
            }
        } message: {
            if let target = uninstallTarget {
                Text("将把「\(target.name)」及其勾选的关联文件移入废纸篓（可恢复）。应用包本身 \(FileSizeFormatter.string(from: target.sizeBytes))。")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Uninstaller")
                    .font(.largeTitle.bold())
                Text("卸载应用并清理其残留文件（一律移入废纸篓，可恢复）")
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if !viewModel.isScanning {
                Button {
                    Task { await viewModel.scan() }
                } label: {
                    Label(viewModel.apps.isEmpty ? "扫描应用" : "重新扫描", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var scanningSection: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("正在统计已安装应用…")
                .foregroundColor(.textSecondary)
            Button("取消", role: .cancel) { viewModel.cancelScan() }
                .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptySection: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundColor(.appAccent)
            Text("尚未扫描")
                .font(.title3.bold())
            Text("扫描 /Applications 与 ~/Applications，查看应用占用与残留文件")
                .font(.callout)
                .foregroundColor(.textSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var listSection: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("搜索应用或 Bundle ID", text: Bindable(viewModel).searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                Text("\(viewModel.filteredApps.count) 个应用 · 共 \(FileSizeFormatter.string(from: viewModel.totalBytes))")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(viewModel.filteredApps) { app in
                    appRow(app)
                    if app.id != viewModel.filteredApps.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: viewModel.icon(for: app.bundleURL.path))
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.callout.bold())
                        .foregroundColor(.textPrimary)
                    if let version = app.version {
                        Text(version)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    if app.isSystemApp {
                        Text("系统应用")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.textSecondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(app.bundleIdentifier ?? app.bundleURL.path)
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                if let lastUsed = app.lastUsedFormatted {
                    Text("最近使用：\(lastUsed)")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Text(FileSizeFormatter.string(from: app.sizeBytes))
                .font(.system(.callout, design: .rounded).monospacedDigit())
                .foregroundColor(.textSecondary)
                .frame(width: 80, alignment: .trailing)

            Button("关联文件") {
                pendingApp = app
                Task { await viewModel.loadAssociations(for: app.id) }
            }
            .buttonStyle(.borderless)
            .disabled(app.isSystemApp)

            Button("卸载") {
                uninstallTarget = app
                showUninstallConfirm = true
                Task { await viewModel.loadAssociations(for: app.id) }
            }
            .buttonStyle(.borderless)
            .foregroundColor(.riskWarning)
            .disabled(app.isSystemApp || viewModel.isUninstalling)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// 关联文件选择面板。
private struct AssociatedFilesSheet: View {
    let app: InstalledApp
    let viewModel: UninstallerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    private var currentApp: InstalledApp {
        viewModel.apps.first(where: { $0.id == app.id }) ?? app
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: viewModel.icon(for: app.bundleURL.path))
                    .resizable()
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.title3.bold())
                    Text(app.bundleIdentifier ?? "")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }

            if viewModel.loadingAssociations == app.id {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("正在查找关联文件…").foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if currentApp.associatedFiles.isEmpty {
                InfoBanner(style: .info, message: "没有找到该应用的关联残留文件。")
            } else {
                Text("关联文件（勾选项会一并移入废纸篓）")
                    .font(.headline)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(currentApp.associatedFiles) { file in
                            HStack(spacing: 8) {
                                Toggle("", isOn: Binding(
                                    get: { viewModel.isSelected(app.id, file.url.path) },
                                    set: { _ in viewModel.toggleAssociated(appID: app.id, path: file.url.path) }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()

                                Text(file.kind)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.appAccent.opacity(0.12))
                                    .clipShape(Capsule())

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(file.displayName)
                                        .font(.callout)
                                        .lineLimit(1)
                                    Text(file.url.path)
                                        .font(.caption2)
                                        .foregroundColor(.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Button {
                                    viewModel.reveal(file.url)
                                } label: {
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.appAccent)
                                }
                                .buttonStyle(.plain)
                                FileSizeText(bytes: file.sizeBytes, font: .caption.monospacedDigit(), color: .textSecondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            HStack {
                Text("已选 \(viewModel.selectedAssociatedBytes(for: currentApp) == 0 ? "" : FileSizeFormatter.string(from: viewModel.selectedAssociatedBytes(for: currentApp)))")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Spacer()
                Button("关闭") { dismiss() }
                Button(working ? "卸载中…" : "卸载应用并清理所选") {
                    working = true
                    Task {
                        await viewModel.uninstall(currentApp)
                        working = false
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(working)
            }
        }
        .padding(24)
        .frame(width: 620, height: 460)
    }
}
