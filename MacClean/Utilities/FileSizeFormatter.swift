import Foundation

enum FileSizeFormatter {
    /// 以 1024 进制格式化字节数，保留一位小数。
    static func string(from bytes: Int64) -> String {
        let absBytes = abs(bytes)
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(absBytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }

        return String(format: "%.1f %@", bytes < 0 ? -value : value, units[unitIndex])
    }
}
