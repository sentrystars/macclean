import Foundation

enum FileSizeFormatter {
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

    static func string(from bytes: Int64, style: NumberFormatter.Style) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
