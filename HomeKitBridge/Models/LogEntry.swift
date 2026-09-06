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

    var title: String {
        switch self {
        case .sync: return "Syncs"
        case .server: return "Local API"
        case .error: return "Problems"
        }
    }

    var symbolName: String {
        switch self {
        case .sync: return "arrow.triangle.2.circlepath"
        case .server: return "point.3.connected.trianglepath.dotted"
        case .error: return "exclamationmark.triangle.fill"
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
