import Foundation

struct ScanProgress: Equatable, Sendable {
    var phase: String
    var currentItem: String
    var filesScanned: Int
    var bytesFound: Int64
    var categoriesCompleted: Int
    var totalCategories: Int

    init(
        phase: String,
        currentItem: String = "",
        filesScanned: Int = 0,
        bytesFound: Int64 = 0,
        categoriesCompleted: Int = 0,
        totalCategories: Int = 1
    ) {
        self.phase = phase
        self.currentItem = currentItem
        self.filesScanned = filesScanned
        self.bytesFound = bytesFound
        self.categoriesCompleted = categoriesCompleted
        self.totalCategories = totalCategories
    }

    var fractionCompleted: Double {
        guard totalCategories > 0 else { return 0 }
        return min(1, Double(categoriesCompleted) / Double(totalCategories))
    }
}

struct CleanProgress: Equatable, Sendable {
    var phase: String
    var currentItem: String
    var itemsCleaned: Int
    var totalItems: Int
    var bytesFreed: Int64
    var failures: [CleanupFailure]

    init(
        phase: String,
        currentItem: String = "",
        itemsCleaned: Int = 0,
        totalItems: Int = 0,
        bytesFreed: Int64 = 0,
        failures: [CleanupFailure] = []
    ) {
        self.phase = phase
        self.currentItem = currentItem
        self.itemsCleaned = itemsCleaned
        self.totalItems = totalItems
        self.bytesFreed = bytesFreed
        self.failures = failures
    }

    var fractionCompleted: Double {
        guard totalItems > 0 else { return 0 }
        return min(1, Double(itemsCleaned) / Double(totalItems))
    }
}
