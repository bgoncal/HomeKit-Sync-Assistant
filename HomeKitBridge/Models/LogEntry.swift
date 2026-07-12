import Foundation
import SwiftUI

enum LogCategory: String, Codable, CaseIterable {
    case sync
    case server
    case error

    var color: Color {
        switch self {
        case .sync: return .blue
        case .server: return .green
        case .error: return .red
        }
    }
}

struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let category: LogCategory
    let message: String
    let details: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), category: LogCategory, message: String, details: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.message = message
        self.details = details
    }
}
