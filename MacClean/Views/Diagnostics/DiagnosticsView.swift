import SwiftUI

struct DiagnosticsView: View {
    @State private var viewModel = DiagnosticsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if !viewModel.hasFullDiskAccess {
                    FullDiskAccessBanner()
                }

                if viewModel.isScanning {
                    scanningSection
                }

                if let info = viewModel.storageInfo {
                    storageInfoSection(info)
                }

                if !viewModel.volumes.isEmpty {
                    volumesSection
                }

                if !viewModel.largeFiles.isEmpty {
                    largeFilesSection
                }

                if !viewModel.largeDirectories.isEmpty {
                    largeDirectoriesSection
                }

                if !viewModel.appBreakdown.isEmpty {
                    appBreakdownSection
                }

                if !viewModel.snapshots.isEmpty {
                    timeMachineSection
                }

                if let result = viewModel.maintenanceResult {
                    MaintenanceResultRow(result: result)
                }

                if let error = viewModel.error {
                    InfoBanner(style: .error, message: error)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appWindowBackground()
        .task { await viewModel.runFullDiagnostics() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Analysis")
                    .font(.largeTitle.bold())
                Text("磁盘占用、大文件与本地快照")
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if !viewModel.isScanning {
                Button {
                    Task { await viewModel.runFullDiagnostics() }
                } label: {
                    Label("重新分析", systemImage: "arrow.clockwise")
                }
                .glassButton()
            }
        }
    }

    private var scanningSection: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("正在分析存储占用…")
                .foregroundColor(.textSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: 16)
    }

    private func storageInfoSection(_ info: StorageInfo) -> some View {
        VStack(spacing: 16) {
            Text("Disk Overview")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 32) {
                StorageDonutChart(
                    segments: [
                        StorageSegment(value: Double(info.usedBytes), color: .storageUsed, label: "Used"),
                        StorageSegment(value: Double(info.freeBytes), color: .storageFree, label: "Free"),
                    ],
                    size: 120
                )

                VStack(alignment: .leading, spacing: 8) {
                    DiskStatRow(label: "Total", value: FileSizeFormatter.string(from: info.totalBytes), color: .textPrimary)
                    DiskStatRow(label: "Used", value: FileSizeFormatter.string(from: info.usedBytes), color: .storageUsed)
                    DiskStatRow(label: "Free", value: FileSizeFormatter.string(from: info.freeBytes), color: .riskSafe)
                    DiskStatRow(label: "Usage", value: "\(Int(info.usagePercentage * 100))%", color: info.usagePercentage > 0.9 ? .riskWarning : .textPrimary)
                }
            }
        }
        .padding()
        .glassPanel(cornerRadius: 12)
    }

    private var largeFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("大文件（按文件，而非目录）")
                .font(.title2.bold())
            Text("大于 \(FileSizeFormatter.string(from: CleanupOptions.current.largeFileThresholdBytes)) 的文件，可在设置中调整阈值")
                .font(.caption)
                .foregroundColor(.textSecondary)

            ForEach(viewModel.largeFiles.prefix(50)) { item in
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.appAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(item.url.deletingLastPathComponent().path)
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    FileSizeText(bytes: item.sizeBytes, font: .callout.monospacedDigit(), color: .textSecondary)
                    Button("移到废纸篓") {
                        Task { await viewModel.moveToTrash(item) }
                    }
                    .buttonStyle(.borderless)
                    Button {
                        viewModel.reveal(item)
                    } label: {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.appAccent)
                    }
                    .buttonStyle(.plain)
                    .help("在 Finder 中显示")
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .glassPanel(cornerRadius: 12)
    }

    private var volumesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已挂载的卷")
                .font(.title2.bold())

            ForEach(viewModel.volumes) { volume in
                HStack(spacing: 12) {
                    Image(systemName: volume.isRemovable ? "externaldrive.fill" : "internaldrive.fill")
                        .foregroundColor(volume.isRemovable ? .purple : .appAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(volume.name)
                                .font(.callout.bold())
                            if volume.isRemovable {
                                Text("外置")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.purple.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(FileSizeFormatter.string(from: volume.usedBytes)) / \(FileSizeFormatter.string(from: volume.totalBytes)) · 可用 \(FileSizeFormatter.string(from: volume.freeBytes))")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    ProgressView(value: min(volume.usagePercentage, 1))
                        .frame(width: 120)

                    Button("分析此卷") {
                        Task { await viewModel.selectVolume(volume.id) }
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isScanning)
                }
                .padding(.vertical, 4)
            }

            if viewModel.selectedVolumeID != nil {
                Button("恢复为「用户主目录」范围") {
                    Task { await viewModel.selectVolume(nil) }
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .glassPanel(cornerRadius: 12)
    }

    private var largeDirectoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Largest Directories")
                    .font(.title2.bold())
                Text("范围：\(viewModel.scopeDescription)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            ForEach(viewModel.largeDirectories) { item in
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.appAccent)
                    Text(item.url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    FileSizeText(bytes: item.sizeBytes, font: .body.monospacedDigit(), color: .textSecondary)
                    Button {
                        viewModel.reveal(item)
                    } label: {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.appAccent)
                    }
                    .buttonStyle(.plain)
                    .help("在 Finder 中显示")
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .glassPanel(cornerRadius: 12)
    }

    private var appBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Storage Breakdown")
                .font(.title2.bold())
            ForEach(viewModel.appBreakdown) { item in
                HStack {
                    Image(systemName: "app.fill")
                        .foregroundColor(.purple)
                    Text(item.displayName)
                        .lineLimit(1)
                    Spacer()
                    FileSizeText(bytes: item.sizeBytes, font: .body.monospacedDigit(), color: .textSecondary)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .glassPanel(cornerRadius: 12)
    }

    private var timeMachineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Time Machine 本地快照")
                    .font(.title2.bold())
                Spacer()
                Button {
                    Task { await viewModel.deleteTimeMachineSnapshots() }
                } label: {
                    if viewModel.isDeletingSnapshots {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Label("清理快照", systemImage: "trash")
                    }
                }
                .glassProminentButton()
                .disabled(viewModel.isDeletingSnapshots)
            }

            ForEach(viewModel.snapshots) { snapshot in
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                    Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                    Spacer()
                    Text(snapshot.id)
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .glassPanel(cornerRadius: 12)
    }
}

struct DiskStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .rounded).monospacedDigit())
                .foregroundColor(.textPrimary)
        }
    }
}