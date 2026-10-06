import Foundation

enum SnapshotParsingTests {

    static func parsesTimestamp() throws {
        let output = """
        Snapshots for volume group containing disk /:
        com.apple.TimeMachine.2024-03-05-142530.local
        com.apple.TimeMachine.2023-12-31-235959.local
        """
        let snapshots = DiagnosticService.parseTimeMachineSnapshots(output)
        try expectEqual(snapshots.count, 2)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: snapshots[0].date)
        try expectEqual(components.year, 2024)
        try expectEqual(components.month, 3)
        try expectEqual(components.day, 5)
        try expectEqual(components.hour, 14)
        try expectEqual(components.minute, 25)
        try expectEqual(components.second, 30)
    }

    static func ignoresNoise() throws {
        let output = """
        Snapshots for volume group containing disk /:
        No local snapshots
        """
        try expectEqual(DiagnosticService.parseTimeMachineSnapshots(output).count, 0)
    }
}

enum FormatterTests {
    static func formatsBytes() throws {
        try expectEqual(FileSizeFormatter.string(from: 0), "0 B")
        try expectEqual(FileSizeFormatter.string(from: 1024), "1.0 KB")
        try expectEqual(FileSizeFormatter.string(from: 1_048_576), "1.0 MB")
        try expectEqual(FileSizeFormatter.string(from: -1024), "-1.0 KB")
    }
}

enum OptionsTests {
    static func exclusionMatching() throws {
        let options = CleanupOptions(
            recycleInsteadOfDelete: false,
            tempMaxAgeDays: 1,
            excludedPaths: ["/Users/example/Downloads"],
            largeFileThresholdBytes: 100
        )
        try expect(options.isExcluded(URL(fileURLWithPath: "/Users/example/Downloads/big.dmg")))
        try expect(!options.isExcluded(URL(fileURLWithPath: "/Users/example/Documents/a.txt")))
    }
}

enum ModelTests {
    static func riskInheritance() throws {
        let item = ScanItem(
            url: URL(fileURLWithPath: CleanupPolicy.home("Library/Caches/com.x")),
            category: .systemCaches,
            sizeBytes: 10,
            isDirectory: true
        )
        try expectEqual(item.riskLevel, .caution)
        try expect(!item.isSelected, "非安全等级默认不应勾选")

        let safe = ScanItem(
            url: URL(fileURLWithPath: CleanupPolicy.home("Library/Caches/com.y")),
            category: .userCaches,
            sizeBytes: 10,
            isDirectory: true
        )
        try expectEqual(safe.riskLevel, .safe)
        try expect(safe.isSelected, "安全等级默认应勾选")

        let archive = ScanItem(
            url: URL(fileURLWithPath: CleanupPolicy.home("Library/Developer/Xcode/Archives/2024/App.xcarchive")),
            category: .xcodeData,
            sizeBytes: 10,
            isDirectory: true,
            riskLevel: .warning
        )
        try expectEqual(archive.riskLevel, .warning)
        try expect(!archive.isSelected, "高风险项默认不勾选")
    }

    static func defaultSelection() throws {
        try expect(CleanupCategory.userCaches.isSelectedByDefault)
        try expect(CleanupCategory.trash.isSelectedByDefault)
        try expect(!CleanupCategory.xcodeData.isSelectedByDefault)
        try expect(!CleanupCategory.claudeVM.isSelectedByDefault)
        try expectEqual(CleanupCategory.appCaches.group, "Application Caches")
        try expectEqual(CleanupCategory.macOSSystem.group, "macOS")
    }
}
