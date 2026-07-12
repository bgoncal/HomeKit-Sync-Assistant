import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var logStore: LogStore

    @State private var search = ""
    @State private var selectedCategory: String = "all"

    private var filtered: [LogEntry] {
        logStore.entries.filter { entry in
            let categoryMatch = selectedCategory == "all" || entry.category.rawValue == selectedCategory
            let searchMatch = search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || entry.message.localizedCaseInsensitiveContains(search)
                || (entry.details?.localizedCaseInsensitiveContains(search) ?? false)
            return categoryMatch && searchMatch
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Logs")
                    .font(.largeTitle.bold())
                Spacer()
                Button("Clear") {
                    logStore.clear()
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                TextField("Search logs", text: $search)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag("all")
                    ForEach(LogCategory.allCases, id: \.rawValue) { c in
                        Text(c.rawValue.capitalized).tag(c.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            List(filtered) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(entry.category.rawValue.uppercased())
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(entry.category.color.opacity(0.18))
                            .foregroundStyle(entry.category.color)
                            .clipShape(Capsule())
                    }
                    Text(entry.message)
                        .font(.headline)
                    if let details = entry.details, !details.isEmpty {
                        Text(details)
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(20)
    }
}
