import SwiftUI

struct LoginItemsView: View {
    @State private var viewModel = LoginItemsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                InfoBanner(
                    style: .info,
                    message: "展示 ~/Library/LaunchAgents、/Library/LaunchAgents 与 /Library/LaunchDaemons。用户级启动项可启停或删除（移入废纸篓）；全局与系统级仅展示，请在「系统设置 → 通用 → 登录项」中管理。"
                )

                if viewModel.isScanning {
                    ProgressView().scaleEffect(1.2).frame(maxWidth: .infinity, minHeight: 100)
                }

                ForEach(viewModel.grouped, id: \.scope) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.scope.displayName)
                            .font(.title3.bold())
                            .foregroundColor(.appAccent)

                        VStack(spacing: 0) {
                            ForEach(section.items) { item in
                                row(item)
                                if item.id != section.items.last?.id { Divider() }
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let message = viewModel.message {
                    InfoBanner(style: .success, message: message)
                }
                if let error = viewModel.error {
                    InfoBanner(style: .error, message: error)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task { await viewModel.scan() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Login Items")
                    .font(.largeTitle.bold())
                Text("查看与管理开机自动运行的进程")
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Button {
                Task { await viewModel.scan() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private func row(_ item: LoginItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.isLoaded ? Color.riskSafe : Color.textSecondary.opacity(0.4))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.callout)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.programDisplay)
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    if item.runAtLoad {
                        Text("开机自启")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.appAccent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if item.scope.requiresPrivilege {
                        Label("系统级", systemImage: "lock.shield")
                            .font(.caption2)
                            .foregroundColor(.riskCaution)
                    }
                }
            }

            Spacer()

            if viewModel.busyItemID == item.id {
                ProgressView().scaleEffect(0.6)
            }

            Text(item.isLoaded ? "运行中" : "已停用")
                .font(.caption)
                .foregroundColor(item.isLoaded ? .riskSafe : .textSecondary)

            Button("Finder") { viewModel.reveal(item) }
                .buttonStyle(.borderless)

            if item.canToggle {
                Button(item.isLoaded ? "停用" : "启用") {
                    Task { await viewModel.setEnabled(item, enabled: !item.isLoaded) }
                }
                .buttonStyle(.borderless)

                Button("删除") {
                    Task { await viewModel.remove(item) }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.riskWarning)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
