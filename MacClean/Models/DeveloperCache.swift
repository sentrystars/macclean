import Foundation

/// 一项开发者缓存（可再生）。
struct DeveloperCacheEntry: Identifiable, Sendable, Hashable {
    let id: String
    let tool: String
    let detail: String
    /// 相对用户主目录的路径。
    let relativePaths: [String]
    /// 绝对路径（需要管理员权限的）。
    let absolutePaths: [String]
    let riskLevel: RiskLevel

    var urls: [URL] {
        relativePaths.map { URL(fileURLWithPath: CleanupPolicy.home($0)) }
            + absolutePaths.map { URL(fileURLWithPath: $0) }
    }
}

/// 开发者缓存清单：路径全部由代码显式枚举，不做通配。
enum DeveloperCacheCatalog {

    static let entries: [DeveloperCacheEntry] = [
        DeveloperCacheEntry(
            id: "npm-cacache", tool: "npm 下载缓存",
            detail: "包下载缓存，删除后重新安装依赖会重新下载",
            relativePaths: [".npm/_cacache"], absolutePaths: [], riskLevel: .safe
        ),
        DeveloperCacheEntry(
            id: "npm-npx", tool: "npx 临时包",
            detail: "npx 执行过的临时包，可安全删除",
            relativePaths: [".npm/_npx"], absolutePaths: [], riskLevel: .safe
        ),
        DeveloperCacheEntry(
            id: "pnpm-store", tool: "pnpm 内容仓库",
            detail: "pnpm 全局 store，删除后下次安装会重新下载",
            relativePaths: ["Library/pnpm/store"], absolutePaths: [], riskLevel: .safe
        ),
        DeveloperCacheEntry(
            id: "uv-cache", tool: "uv / pip 缓存",
            detail: "Python 包下载缓存",
            relativePaths: [".cache/uv", "Library/Caches/pip"], absolutePaths: [], riskLevel: .safe
        ),
        DeveloperCacheEntry(
            id: "puppeteer", tool: "Puppeteer 浏览器",
            detail: "Puppeteer 下载的 Chromium，删除后需重新下载",
            relativePaths: [".cache/puppeteer"], absolutePaths: [], riskLevel: .safe
        ),
        DeveloperCacheEntry(
            id: "codex-runtimes", tool: "Codex 运行时缓存",
            detail: "命令行工具自带的运行时缓存",
            relativePaths: [".cache/codex-runtimes"], absolutePaths: [], riskLevel: .safe
        ),
        DeveloperCacheEntry(
            id: "selenium", tool: "Selenium 驱动缓存",
            detail: "WebDriver 缓存",
            relativePaths: [".cache/selenium"], absolutePaths: [], riskLevel: .safe
        ),
        DeveloperCacheEntry(
            id: "huggingface", tool: "HuggingFace 模型缓存",
            detail: "下载的模型文件，删除后需要重新下载（可能很大）",
            relativePaths: [".cache/huggingface"], absolutePaths: [], riskLevel: .caution
        ),
        DeveloperCacheEntry(
            id: "gradle-caches", tool: "Gradle 缓存",
            detail: "依赖与构建缓存，删除后首次构建会变慢",
            relativePaths: [".gradle/caches"], absolutePaths: [], riskLevel: .safe
        ),
        DeveloperCacheEntry(
            id: "maven-repo", tool: "Maven 本地仓库",
            detail: "已下载的依赖 jar，删除后需要重新下载",
            relativePaths: [".m2/repository"], absolutePaths: [], riskLevel: .caution
        ),
        DeveloperCacheEntry(
            id: "cargo-registry", tool: "Cargo 依赖缓存",
            detail: "Rust 依赖源码与编译产物",
            relativePaths: [".cargo/registry"], absolutePaths: [], riskLevel: .caution
        ),
        DeveloperCacheEntry(
            id: "rustup-downloads", tool: "rustup 下载缓存",
            detail: "工具链安装包缓存，可安全删除",
            relativePaths: [".rustup/downloads"], absolutePaths: [], riskLevel: .safe
        ),
        DeveloperCacheEntry(
            id: "coreSimulator-caches", tool: "iOS 模拟器缓存",
            detail: "CoreSimulator 运行时缓存，系统会自动重建",
            relativePaths: [], absolutePaths: ["/Library/Developer/CoreSimulator/Caches"], riskLevel: .safe
        ),
    ]

    /// 允许清理的路径（精确匹配或前缀）。
    static let allowedPaths: [String] = entries.flatMap { $0.urls.map(\.path) }

    static func isDeveloperCachePath(_ path: String) -> Bool {
        allowedPaths.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    static func entry(for path: String) -> DeveloperCacheEntry? {
        entries.first { entry in
            entry.urls.contains { path == $0.path || path.hasPrefix($0.path + "/") }
        }
    }
}
