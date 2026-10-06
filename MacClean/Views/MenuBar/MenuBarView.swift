import AppKit
import SwiftUI

/// 菜单栏面板：磁盘概况 + 常用快捷操作。
struct MenuBarView: View {
    @State private var store = StorageStore.shared
    @State private var scheduler = AutoCleanScheduler.shared
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let info = store.storageInfo {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MacClean")
                        .font(.headline)
                    Text("已用 \(FileSizeFormatter.string(from: info.usedBytes)) / \(FileSizeFormatter.string(from: info.totalBytes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView(value: min(info.usagePercentage, 1))
                    Text("可用 \(FileSizeFormatter.string(from: info.freeBytes))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.6)
                    Text("正在读取磁盘信息…").font(.caption)
                }
            }

            Divider()

            Button("打开主窗口") { open(.dashboard) }
            Button("清理缓存") { open(.cacheCleanup) }
            Button("深度清理") { open(.deepCleanup) }
            Button("存储分析") { open(.storageAnalysis) }
            Button("清空废纸篓") { open(.trash) }

            if UserDefaults.standard.bool(forKey: SettingsKey.weeklyAutoCleanEnabled) {
                Divider()
                Button("立即执行自动清理") {
                    Task { await scheduler.runNow() }
                }
                if let lastRun = scheduler.lastRun {
                    Text("上次自动清理：\(lastRun.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Button("刷新") { Task { await store.refresh(force: true) } }
            Button("退出 MacClean") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 260)
        .task { await store.refresh() }
    }

    private func open(_ item: SidebarItem) {
        appVM.selectedSidebarItem = item
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
    }
}
