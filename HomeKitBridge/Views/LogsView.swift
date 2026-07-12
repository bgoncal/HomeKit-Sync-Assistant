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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity")
                        .font(.largeTitle.bold())
                    Text("Recent sync, server, and connection events.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    logStore.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Search activity", text: $search)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag("all")
                    ForEach(LogCategory.allCases, id: \.rawValue) { category in
                        Text(categoryTitle(category)).tag(category.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }

            if filtered.isEmpty {
                Spacer()
                ContentUnavailableView("No Activity", systemImage: "clock", description: Text("Matching events will appear here as the bridge runs."))
                Spacer()
            } else {
                List(filtered) { entry in
                    logRow(entry)
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(20)
        .navigationTitle("Activity")
    }

    private func logRow(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(categoryTitle(entry.category), systemImage: icon(for: entry.category))
                    .font(.caption.bold())
                    .foregroundStyle(entry.category.color)
                Spacer()
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.message)
                .font(.headline)

            if let details = entry.details, !details.isEmpty {
                DisclosureGroup("Details") {
                    Text(details)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
                .font(.callout)
            }
        }
    }

    private func categoryTitle(_ category: LogCategory) -> String {
        switch category {
        case .sync: return "Sync"
        case .server: return "Server"
        case .error: return "Errors"
        }
    }

    private func icon(for category: LogCategory) -> String {
        switch category {
        case .sync: return "arrow.triangle.2.circlepath"
        case .server: return "server.rack"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
