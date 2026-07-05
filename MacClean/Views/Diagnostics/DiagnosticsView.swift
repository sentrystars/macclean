import SwiftUI

struct DiagnosticsView: View {
    @State private var viewModel = DiagnosticsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Storage Analysis")
                            .font(.largeTitle.bold())
                        Text("Detailed view of disk usage and large files")
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    if !viewModel.isScanning {
                        Button(action: { Task { await viewModel.runFullDiagnostics() } }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if viewModel.isScanning {
                    scanningSection
                }

                if let info = viewModel.storageInfo {
                    storageInfoSection(info)
                }

                if !viewModel.largeDirectories.isEmpty {
                    largeDirectoriesSection
                }

                if !viewModel.appBreakdown.isEmpty {
                    appBreakdownSection
                }

                if !viewModel.timeMachineSnapshots.isEmpty {
                    timeMachineSection
                }

                if viewModel.error != nil {
                    errorSection
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task { await viewModel.runFullDiagnostics() }
    }

    private var scanningSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing storage...")
                .foregroundColor(.textSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var largeDirectoriesSection: some View {
        VStack(spacing: 8) {
            Text("Largest Directories")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.largeDirectories) { item in
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.appAccent)
                    Text(item.url.lastPathComponent)
                        .lineLimit(1)
                    Spacer()
                    FileSizeText(bytes: item.sizeBytes, font: .body.monospacedDigit(), color: .textSecondary)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var appBreakdownSection: some View {
        VStack(spacing: 8) {
            Text("App Storage Breakdown")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.appBreakdown) { item in
                HStack {
                    Image(systemName: "app.fill")
                        .foregroundColor(.purple)
                    Text(item.subcategory ?? item.url.lastPathComponent)
                        .lineLimit(1)
                    Spacer()
                    FileSizeText(bytes: item.sizeBytes, font: .body.monospacedDigit(), color: .textSecondary)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var timeMachineSection: some View {
        VStack(spacing: 8) {
            Text("Time Machine Snapshots")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.timeMachineSnapshots) { snapshot in
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                    Text(snapshot.date, style: .date)
                    Spacer()
                    Text(snapshot.id.suffix(8).prefix(8).description)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var errorSection: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.riskCaution)
            Text(viewModel.error ?? "Unknown error")
                .foregroundColor(.textSecondary)
        }
        .padding()
        .background(Color.riskCaution.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DiskStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .rounded).monospacedDigit())
                .foregroundColor(.textPrimary)
        }
    }
}
