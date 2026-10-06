import Foundation

/// 扫描计划：把「某个分类怎么扫」抽象成可并发执行的任务。
///
/// 放在 Models 层，供视图模型与后台服务（如自动清理调度）共用。
struct ScanPlan: Sendable {
    let name: String
    let makeStream: @Sendable (ScanService) -> AsyncStream<ScanItem>
}

extension ScanPlan {
    /// 默认扫描计划（缓存清理 / 智能扫描）。
    static let standard: [ScanPlan] = [
        ScanPlan(name: "用户缓存") { $0.scanUserCaches() },
        ScanPlan(name: "用户日志") { $0.scanUserLogs() },
        ScanPlan(name: "应用容器缓存") { $0.scanContainerCaches() },
        ScanPlan(name: "应用缓存") { $0.scanAppCaches() },
        ScanPlan(name: "开发者缓存") { $0.scanDeveloperCaches() },
        ScanPlan(name: "系统数据") { service in service.scanSystemData(options: .current) },
        ScanPlan(name: "macOS 系统") { $0.scanMacOSSystem() },
        ScanPlan(name: "Claude VM") { $0.scanClaudeVM() },
        ScanPlan(name: "Xcode 数据") { $0.scanXcodeData() },
        ScanPlan(name: "废纸篓") { $0.scanTrash() },
    ]
}