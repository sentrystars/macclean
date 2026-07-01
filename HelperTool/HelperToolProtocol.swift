import Foundation

@objc protocol HelperToolProtocol {
    func removeItems(at paths: [String], reply: @escaping (Error?) -> Void)
    func removeDirectoryContents(at path: String, maxDaysOld: Int?, reply: @escaping (Error?) -> Void)
    func flushDNSCache(reply: @escaping (Error?) -> Void)
    func getDirectorySize(at path: String, reply: @escaping (Int64, Error?) -> Void)
    func getDiskInfo(reply: @escaping ([String: Int64]?, Error?) -> Void)
}
