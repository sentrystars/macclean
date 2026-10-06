import Foundation

/// 「系统数据」构成项的安全等级。
enum SystemDataSafety: String, Sendable, CaseIterable {
    /// 可再生，可安全清理
    case cleanable
    /// 需要确认后再清理
    case review
    /// 由系统管理，不建议手动删除
    case systemManaged

    var displayName: String {
        switch self {
        case .cleanable: return "可清理"
        case .review: return "需确认"
        case .systemManaged: return "系统管理"
        }
    }
}

/// 一个系统数据构成桶。
struct SystemDataBucket: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let paths: [String]
    let safety: SystemDataSafety
    let sizeBytes: Int64
}
