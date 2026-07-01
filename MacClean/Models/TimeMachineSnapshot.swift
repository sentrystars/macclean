import Foundation

struct TimeMachineSnapshot: Identifiable, Sendable {
    let id: String
    let date: Date
    let volume: String
    let sizeBytes: Int64?
}
