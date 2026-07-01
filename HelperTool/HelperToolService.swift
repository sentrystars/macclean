import Foundation

class HelperToolService: NSObject, HelperToolProtocol {
    private let fileManager = FileManager.default

    // MARK: - Remove Items
    func removeItems(at paths: [String], reply: @escaping (Error?) -> Void) {
        for path in paths {
            guard isPathAllowed(path) else {
                reply(NSError(domain: "com.macclean.helper", code: 403,
                            userInfo: [NSLocalizedDescriptionKey: "Path not allowed: \(path)"]))
                return
            }

            let url = URL(fileURLWithPath: path)
            guard fileManager.fileExists(atPath: path) else { continue }

            do {
                try fileManager.removeItem(at: url)
            } catch {
                reply(error)
                return
            }
        }
        reply(nil)
    }

    // MARK: - Remove Directory Contents
    func removeDirectoryContents(at path: String, maxDaysOld: Int?, reply: @escaping (Error?) -> Void) {
        guard isPathAllowed(path) else {
            reply(NSError(domain: "com.macclean.helper", code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "Path not allowed: \(path)"]))
            return
        }

        let url = URL(fileURLWithPath: path)
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            reply(nil)
            return
        }

        for itemURL in contents {
            var shouldDelete = true

            if let maxDays = maxDaysOld, maxDays > 0 {
                if let attrs = try? fileManager.attributesOfItem(atPath: itemURL.path),
                   let modDate = attrs[.modificationDate] as? Date {
                    let age = Date().timeIntervalSince(modDate) / (60 * 60 * 24)
                    shouldDelete = age > Double(maxDays)
                }
            }

            if shouldDelete {
                try? fileManager.removeItem(at: itemURL)
            }
        }
        reply(nil)
    }

    // MARK: - Flush DNS
    func flushDNSCache(reply: @escaping (Error?) -> Void) {
        let process1 = Process()
        process1.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        process1.arguments = ["-flushcache"]
        process1.runAndWait()

        let process2 = Process()
        process2.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process2.arguments = ["-HUP", "mDNSResponder"]
        process2.runAndWait()

        reply(nil)
    }

    // MARK: - Get Directory Size
    func getDirectorySize(at path: String, reply: @escaping (Int64, Error?) -> Void) {
        guard isPathAllowed(path) else {
            reply(0, NSError(domain: "com.macclean.helper", code: 403,
                           userInfo: [NSLocalizedDescriptionKey: "Path not allowed: \(path)"]))
            return
        }

        let url = URL(fileURLWithPath: path)
        var total: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            reply(0, nil)
            return
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize
            else { continue }
            total += Int64(fileSize)
        }

        reply(total, nil)
    }

    // MARK: - Get Disk Info
    func getDiskInfo(reply: @escaping ([String: Int64]?, Error?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/df")
        process.arguments = ["-k", "/"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                reply(nil, NSError(domain: "com.macclean.helper", code: 500,
                                 userInfo: [NSLocalizedDescriptionKey: "Failed to read disk info"]))
                return
            }

            let lines = output.split(separator: "\n")
            guard lines.count >= 2 else {
                reply(nil, nil)
                return
            }

            let parts = lines[1].split(separator: " ", omittingEmptySubstrings: true)
            guard parts.count >= 4 else {
                reply(nil, nil)
                return
            }

            let info: [String: Int64] = [
                "total": (Int64(parts[1]) ?? 0) * 1024,
                "used": (Int64(parts[2]) ?? 0) * 1024,
                "free": (Int64(parts[3]) ?? 0) * 1024,
            ]
            reply(info, nil)
        } catch {
            reply(nil, error)
        }
    }

    // MARK: - Path Validation
    private func isPathAllowed(_ path: String) -> Bool {
        let allowedPrefixes = [
            "/Library/Caches",
            "/Library/Logs",
            "/private/tmp",
            "/private/var/tmp",
            "/private/var/folders",
            "/private/var/vm",
            "/System/Library/Caches",
        ]
        return allowedPrefixes.contains { path.hasPrefix($0) }
    }
}

// MARK: - Process Sync Helper
extension Process {
    func runAndWait() {
        try? run()
        waitUntilExit()
    }
}

// MARK: - XPC Delegate
class HelperToolDelegate: NSObject, NSXPCListenerDelegate {
    let service = HelperToolService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperToolProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}
