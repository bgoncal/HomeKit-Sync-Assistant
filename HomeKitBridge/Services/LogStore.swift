import Foundation

@MainActor
final class LogStore: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []

    private let key = "logEntries"
    private let maxEntries = 500

    init() {
        load()
    }

    func add(category: LogCategory, message: String, details: String? = nil) {
        let entry = LogEntry(category: category, message: message, details: details)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            entries = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
