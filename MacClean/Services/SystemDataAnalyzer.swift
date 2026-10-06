import Foundation

/// 「系统数据」分析器。
///
/// 对应 macOS「存储空间」里那个说不清的 System Data：把可枚举的构成项
/// 逐个量出来，并按「可清理 / 需确认 / 系统管理」分级。
final class SystemDataAnalyzer: Sendable {

    struct Spec: Sendable {
        let id: String
        let title: String
        let detail: String
        let paths: [String]
        let safety: SystemDataSafety
    }

    static var specs: [Spec] {
        let home = CleanupPolicy.home
        return [
            Spec(id: "sim-runtimes", title: "iOS 模拟器运行时",
                 detail: "Xcode 下载的模拟器系统镜像；删除后无法运行对应版本模拟器",
                 paths: ["/Library/Developer/CoreSimulator/Volumes"], safety: .review),
            Spec(id: "sim-caches", title: "iOS 模拟器缓存",
                 detail: "CoreSimulator 运行时缓存，系统会自动重建",
                 paths: ["/Library/Developer/CoreSimulator/Caches"], safety: .cleanable),
            Spec(id: "command-line-tools", title: "命令行工具",
                 detail: "Command Line Tools（开发必需，不建议删除）",
                 paths: ["/Library/Developer/CommandLineTools"], safety: .systemManaged),
            Spec(id: "user-developer", title: "模拟器设备与开发数据",
                 detail: "~/Library/Developer 下的模拟器设备、设备支持等",
                 paths: [home("Library/Developer")], safety: .review),
            Spec(id: "npm", title: "npm 缓存",
                 detail: "node 包下载缓存（_cacache / _npx）",
                 paths: [home(".npm")], safety: .cleanable),
            Spec(id: "dot-cache", title: "工具缓存 .cache",
                 detail: "uv / puppeteer / huggingface 等工具的下载缓存",
                 paths: [home(".cache")], safety: .cleanable),
            Spec(id: "rustup", title: "Rust 工具链",
                 detail: "rustup 工具链与下载缓存",
                 paths: [home(".rustup")], safety: .review),
            Spec(id: "pnpm", title: "pnpm 内容仓库",
                 detail: "pnpm 全局 store",
                 paths: [home("Library/pnpm")], safety: .cleanable),
            Spec(id: "jvm", title: "Gradle / Maven",
                 detail: "JVM 生态的依赖与构建缓存",
                 paths: [home(".gradle"), home(".m2")], safety: .cleanable),
            Spec(id: "other-dev", title: "其他开发工具目录",
                 detail: "rbenv / gem / cargo / local 等",
                 paths: [home(".rbenv"), home(".gem"), home(".cargo"), home(".local")], safety: .review),
            Spec(id: "ai-tools", title: "AI 工具数据",
                 detail: "Codex / Claude / DSH 的插件与会话记录",
                 paths: [home(".codex"), home(".claude"), home(".dsh"), home(".cc-switch")], safety: .review),
            Spec(id: "ollama", title: "Ollama 本地模型",
                 detail: "本地大模型权重，按需保留",
                 paths: [home(".ollama")], safety: .review),
            Spec(id: "app-support", title: "应用支持数据",
                 detail: "~/Library/Application Support：各应用的数据与缓存",
                 paths: [home("Library/Application Support")], safety: .review),
            Spec(id: "containers", title: "应用沙盒容器",
                 detail: "~/Library/Containers",
                 paths: [home("Library/Containers")], safety: .review),
            Spec(id: "user-caches", title: "用户缓存",
                 detail: "~/Library/Caches",
                 paths: [home("Library/Caches")], safety: .cleanable),
            Spec(id: "user-logs", title: "用户日志",
                 detail: "~/Library/Logs",
                 paths: [home("Library/Logs")], safety: .cleanable),
            Spec(id: "system-caches", title: "系统缓存与日志",
                 detail: "/Library/Caches 与 /Library/Logs",
                 paths: ["/Library/Caches", "/Library/Logs"], safety: .cleanable),
            Spec(id: "system-support", title: "系统应用支持",
                 detail: "/Library/Application Support",
                 paths: ["/Library/Application Support"], safety: .review),
            Spec(id: "system-db", title: "系统数据库与诊断",
                 detail: "日志、电源、符号数据库（diagnostics / powerlog / uuidtext）",
                 paths: ["/private/var/db"], safety: .systemManaged),
            Spec(id: "vm", title: "虚拟内存与睡眠镜像",
                 detail: "swap 与 sleepimage，由系统管理",
                 paths: ["/private/var/vm"], safety: .systemManaged),
            Spec(id: "var-folders", title: "系统临时目录",
                 detail: "/private/var/folders，由系统回收",
                 paths: ["/private/var/folders"], safety: .systemManaged),
            Spec(id: "shared", title: "共享目录残留",
                 detail: "/Users/Shared：系统升级后移出的旧文件",
                 paths: ["/Users/Shared"], safety: .cleanable),
        ]
    }

    /// 逐桶产出（边算边显示）。
    func analyze() -> AsyncStream<SystemDataBucket> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task.detached(priority: .utility) {
                for spec in Self.specs {
                    if Task.isCancelled { break }
                    let size = spec.paths.reduce(Int64(0)) { partial, path in
                        partial + Self.size(ofPath: path)
                    }
                    let bucket = SystemDataBucket(
                        id: spec.id,
                        title: spec.title,
                        detail: spec.detail,
                        paths: spec.paths,
                        safety: spec.safety,
                        sizeBytes: size
                    )
                    continuation.yield(bucket)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 本地快照数量（快照没有 root 拿不到大小，只报数量）。
    func snapshotCount() async -> Int {
        await DiagnosticService().getTimeMachineSnapshots().count
    }

    static func size(ofPath path: String) -> Int64 {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: path, isDirectory: &isDirectory) else { return 0 }
        if isDirectory.boolValue {
            return manager.directorySize(at: URL(fileURLWithPath: path))
        }
        return (try? manager.attributesOfItem(atPath: path))?[.size] as? Int64 ?? 0
    }
}
