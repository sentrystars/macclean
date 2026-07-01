import Foundation

struct ScanProgress: Equatable, Sendable {
    let phase: String
    let currentItem: String
    let filesScanned: Int
    let bytesFound: Int64
    let categoriesCompleted: Int
    let totalCategories: Int

    var fractionCompleted: Double {
        guard totalCategories > 0 else { return 0 }
        return Double(categoriesCompleted) / Double(totalCategories)
    }
}

struct CleanProgress: Equatable, Sendable {
    let phase: String
    let currentItem: String
    let itemsCleaned: Int
    let totalItems: Int
    let bytesFreed: Int64

    var fractionCompleted: Double {
        guard totalItems > 0 else { return 0 }
        return Double(itemsCleaned) / Double(totalItems)
    }
}
