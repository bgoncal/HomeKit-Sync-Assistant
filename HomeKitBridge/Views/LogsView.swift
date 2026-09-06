import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var logStore: LogStore

    @State private var search = ""
    @State private var selectedCategory: LogFilter = .all

    var body: some View {
        LogsContent(
            entries: logStore.entries,
            search: $search,
            selectedCategory: $selectedCategory,
            onClear: { logStore.clear() }
        )
    }
}

enum LogFilter: Hashable {
    case all
    case category(LogCategory)

    var title: String {
        switch self {
        case .all: return "All"
        case .category(let category): return category.title
        }
    }

    static var allCases: [LogFilter] {
        [.all] + LogCategory.allCases.map(LogFilter.category)
    }
}

/// A record of everything the bridge has done.
struct LogsContent: View {
    let entries: [LogEntry]
    @Binding var search: String
    @Binding var selectedCategory: LogFilter
    var onClear: () -> Void = {}

    private var filtered: [LogEntry] {
        entries.filter { entry in
            let categoryMatch: Bool
            switch selectedCategory {
            case .all: categoryMatch = true
            case .category(let category): categoryMatch = entry.category == category
            }

            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatch = query.isEmpty
                || entry.message.localizedCaseInsensitiveContains(query)
                || (entry.details?.localizedCaseInsensitiveContains(query) ?? false)

            return categoryMatch && searchMatch
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity")
                        .font(.largeTitle.bold())
                    Text("Every change the bridge applied, plus connection and local API events.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button(action: onClear) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(entries.isEmpty)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Search activity", text: $search)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $selectedCategory) {
                    ForEach(LogFilter.allCases, id: \.self) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
            }

            if filtered.isEmpty {
                Spacer()
                ContentUnavailableView(
                    entries.isEmpty ? "Nothing has happened yet" : "No matching activity",
                    systemImage: "clock",
                    description: Text(entries.isEmpty
                        ? "Applied changes, connection problems, and local API events show up here."
                        : "Try a different search or category.")
                )
                Spacer()
            } else {
                List(filtered) { entry in
                    logRow(entry)
                        .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func logRow(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(entry.category.title, systemImage: entry.category.symbolName)
                    .font(.caption.bold())
                    .foregroundStyle(entry.category.color)
                Spacer()
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.message)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

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
}
