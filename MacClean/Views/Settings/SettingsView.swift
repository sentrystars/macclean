import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.recycleInsteadOfDelete) private var recycleInsteadOfDelete = false
    @AppStorage(SettingsKey.confirmBeforeClean) private var confirmBeforeClean = true
    @AppStorage(SettingsKey.autoSelectSafeItems) private var autoSelectSafeItems = true
    @AppStorage(SettingsKey.tempMaxAgeDays) private var tempMaxAgeDays = 1
    @AppStorage(SettingsKey.largeFileThresholdMB) private var largeFileThresholdMB = 500
    @AppStorage(SettingsKey.hideFullDiskAccessWarning) private var hideFullDiskAccessWarning = false
    @AppStorage(SettingsKey.lowDiskAlertEnabled) private var lowDiskAlertEnabled = false
    @AppStorage(SettingsKey.lowDiskThresholdGB) private var lowDiskThresholdGB = 10
    @AppStorage(SettingsKey.weeklyAutoCleanEnabled) private var weeklyAutoCleanEnabled = false
    private let scheduler = AutoCleanScheduler.shared

    @State private var exclusions: [String] = UserDefaults.standard.stringArray(forKey: SettingsKey.excludedPaths) ?? []
    @State private var newExclusion = ""
    private var history = CleanupHistory.shared

    var body: some View {
        Form {
            Section("清理行为") {
                Toggle("删除时移入废纸篓（可恢复，但不会立即释放空间）", isOn: $recycleInsteadOfDelete)
                Toggle("清理前二次确认", isOn: $confirmBeforeClean)
                Toggle("默认勾选「安全」级别项目", isOn: $autoSelectSafeItems)
            }

            Section("扫描范围") {
                Stepper("临时文件保留天数：\(tempMaxAgeDays) 天", value: $tempMaxAgeDays, in: 1...30)
                Stepper("大文件阈值：\(largeFileThresholdMB) MB", value: $largeFileThresholdMB, in: 50...10_000, step: 50)
            }

            Section("排除列表") {
                if exclusions.isEmpty {
                    Text("没有排除项")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(exclusions, id: \.self) { path in
                        HStack {
                            Text(path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("移除") {
                                exclusions.removeAll { $0 == path }
                                persistExclusions()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                HStack {
                    TextField("要排除的绝对路径", text: $newExclusion)
                    Button("添加") {
                        let trimmed = newExclusion.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("/"), !exclusions.contains(trimmed) else { return }
                        exclusions.append(trimmed)
                        newExclusion = ""
                        persistExclusions()
                    }
                    .disabled(!newExclusion.trimmingCharacters(in: .whitespaces).hasPrefix("/"))
                }
            }

            Section("权限") {
                Toggle("不再提示「完全磁盘访问」授权", isOn: $hideFullDiskAccessWarning)
                Button("打开「完全磁盘访问」系统设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Section("提醒与自动化") {
                Toggle("磁盘空间不足时发送系统通知", isOn: $lowDiskAlertEnabled)
                Stepper("剩余空间低于 \(lowDiskThresholdGB) GB 时提醒", value: $lowDiskThresholdGB, in: 1...100)
                Toggle("每周自动清理安全级别缓存（一律移入废纸篓）", isOn: $weeklyAutoCleanEnabled)
                if weeklyAutoCleanEnabled {
                    if let lastRun = scheduler.lastRun {
                        Text("上次自动执行：\(lastRun.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Button("立即执行一次") {
                        Task { await scheduler.runNow() }
                    }
                }
            }

            Section("历史") {
                Text("已记录 \(history.records.count) 次清理，累计释放 \(FileSizeFormatter.string(from: history.totalFreedBytes))")
                    .font(.callout)
                Button("清空清理历史", role: .destructive) {
                    history.reset()
                }
                .disabled(history.records.isEmpty)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 460)
    }

    private func persistExclusions() {
        UserDefaults.standard.set(exclusions, forKey: SettingsKey.excludedPaths)
    }
}