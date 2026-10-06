import Foundation

/// 一个 iOS/watchOS/tvOS/visionOS 模拟器运行时（磁盘镜像）。
struct SimulatorRuntime: Identifiable, Sendable, Hashable {
    let identifier: String
    let platformName: String
    let version: String
    let build: String
    let state: String
    let isDeletable: Bool
    let sizeBytes: Int64
    let mountPath: String?
    let lastUsedAt: Date?

    var id: String { identifier }

    /// 展示名，例如 "iOS 27.0 (24A5370g)"。
    var displayName: String {
        build.isEmpty ? "\(platformName) \(version)" : "\(platformName) \(version) (\(build))"
    }

    var isReady: Bool { state.caseInsensitiveCompare("Ready") == .orderedSame }

    var sizeFormatted: String { FileSizeFormatter.string(from: sizeBytes) }

    var lastUsedFormatted: String? {
        guard let lastUsedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUsedAt, relativeTo: Date())
    }

    var iconName: String {
        switch platformName {
        case "watchOS": return "applewatch"
        case "tvOS": return "appletv"
        case "visionOS": return "visionpro"
        default: return "iphone"
        }
    }
}

/// 模拟器设备汇总（用于提示「不可用设备」）。
struct SimulatorDeviceSummary: Sendable, Equatable {
    let total: Int
    let unavailable: Int
    let booted: Int

    static let empty = SimulatorDeviceSummary(total: 0, unavailable: 0, booted: 0)
}

enum SimulatorError: Error, LocalizedError {
    case xcodeUnavailable
    case invalidResponse
    case unknownRuntime(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .xcodeUnavailable: return "未检测到 Xcode，模拟器功能需要完整安装的 Xcode"
        case .invalidResponse: return "无法解析 simctl 输出"
        case .unknownRuntime(let id): return "运行时不存在或已删除：\(id)"
        case .deleteFailed(let message): return message
        }
    }
}

enum SimulatorRuntimeParser {

    static let platformNames: [String: String] = [
        "com.apple.platform.iphonesimulator": "iOS",
        "com.apple.platform.watchsimulator": "watchOS",
        "com.apple.platform.appletvsimulator": "tvOS",
        "com.apple.platform.xrsimulator": "visionOS",
    ]

    /// 解析 simctl runtime list -j 的 JSON。
    static func parse(json data: Data) throws -> [SimulatorRuntime] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SimulatorError.invalidResponse
        }
        let runtimes: [SimulatorRuntime] = root.compactMap { key, value in
            guard let object = value as? [String: Any] else { return nil }
            let identifier = (object["identifier"] as? String) ?? key
            return makeRuntime(identifier: identifier, object: object)
        }
        return runtimes.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    /// 解析文本格式（老版本 simctl 的兜底）：
    /// "iOS 27.0 (24A5370g) - 8FC67D3A-... (Ready)"
    static func parse(text: String) -> [SimulatorRuntime] {
        var runtimes: [SimulatorRuntime] = []
        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // 必须在 " - " **之后**找括号：版本行形如
            // "iOS 27.0 (24A5370g) - <UUID> (Ready)"，第一个 " (" 在短横线之前。
            guard let dashRange = line.range(of: " - ") else { continue }
            let tail = line[dashRange.upperBound...]
            guard let openParen = tail.range(of: " ("),
                  let closeParen = tail.range(of: ")", options: .backwards),
                  openParen.lowerBound < closeParen.lowerBound
            else { continue }

            let identifier = String(tail[tail.startIndex..<openParen.lowerBound])
            guard isSafeIdentifier(identifier) else { continue }

            // head 形如 "iOS 27.0 (24A5370g)"
            let headParts = line[line.startIndex..<dashRange.lowerBound]
                .split(separator: " ")
                .map(String.init)
            let state = String(tail[openParen.upperBound..<closeParen.lowerBound])
            let platform = headParts.first ?? "iOS"
            let version = headParts.count > 1 ? headParts[1] : ""
            let build = headParts.count > 2
                ? headParts[2].trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                : ""

            runtimes.append(SimulatorRuntime(
                identifier: identifier,
                platformName: platform.isEmpty ? "iOS" : platform,
                version: version,
                build: build,
                state: state,
                isDeletable: true,
                sizeBytes: 0,
                mountPath: nil,
                lastUsedAt: nil
            ))
        }
        return runtimes
    }

    private static func makeRuntime(identifier: String, object: [String: Any]) -> SimulatorRuntime {
        let platformIdentifier = object["platformIdentifier"] as? String
        var platform = platformNames[platformIdentifier ?? ""] ?? ""
        if platform.isEmpty, let runtimeIdentifier = object["runtimeIdentifier"] as? String,
           let range = runtimeIdentifier.range(of: "SimRuntime.") {
            let tail = runtimeIdentifier[range.upperBound...]
            platform = tail.split(separator: "-").first.map(String.init) ?? ""
        }

        return SimulatorRuntime(
            identifier: identifier,
            platformName: platform.isEmpty ? "iOS" : platform,
            version: object["version"] as? String ?? "",
            build: object["build"] as? String ?? "",
            state: object["state"] as? String ?? "Unknown",
            isDeletable: object["deletable"] as? Bool ?? false,
            sizeBytes: (object["sizeBytes"] as? NSNumber)?.int64Value ?? 0,
            mountPath: object["mountPath"] as? String,
            lastUsedAt: parseDate(object["lastUsedAt"] as? String)
        )
    }

    /// 解析 ISO8601 时间（使用 Sendable 的 FormatStyle，避免共享 Formatter）。
    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return try? Date(value, strategy: .iso8601)
    }

    /// 只接受 UUID 形状的标识符，避免把任意字符串拼进命令。
    static func isSafeIdentifier(_ identifier: String) -> Bool {
        guard identifier.count == 36 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF-")
        return identifier.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
