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

enum LogFilter: Hashable, CaseIterable {
    case all
    case syncs
    case localAPI
    case problems

    var title: String {
        switch self {
        case .all: return "All"
        case .syncs: return LogCategory.sync.title
        case .localAPI: return LogCategory.server.title
        case .problems: return LogCategory.error.title
        }
    }

    var category: LogCategory? {
        switch self {
        case .all: return nil
        case .syncs: return .sync
        case .localAPI: return .server
        case .problems: return .error
        }
    }
}

/// A record of everything the bridge has done.
struct LogsContent: View {
    let entries: [LogEntry]
    @Binding var search: String
    @Binding var selectedCategory: LogFilter
    var onClear: () -> Void = {}

    private var filtered: [LogEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            let categoryMatch = selectedCategory.category.map { $0 == entry.category } ?? true
            let searchMatch = query.isEmpty
                || entry.message.localizedCaseInsensitiveContains(query)
                || (entry.details?.localizedCaseInsensitiveContains(query) ?? false)
            return categoryMatch && searchMatch
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { entry in
                row(entry)
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Search activity")
        .overlay {
            if filtered.isEmpty {
                emptyState
            }
        }
        .navigationTitle("Activity")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Show", selection: $selectedCategory) {
                        ForEach(LogFilter.allCases, id: \.self) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    Section {
                        Button("Clear Activity", systemImage: "trash", role: .destructive, action: onClear)
                            .disabled(entries.isEmpty)
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: exportedLog,
                    preview: SharePreview("Home Sync Assistant activity")
                ) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(filtered.isEmpty)
            }
        }
    }

    /// What the export button hands over: the visible rows, oldest first, as text
    /// that can be pasted into an issue or a mail.
    private var exportedLog: String {
        let header = "Home Sync Assistant · activity export · \(Date().formatted(date: .abbreviated, time: .shortened))"
        let lines = filtered.reversed().map { entry -> String in
            let timestamp = entry.timestamp.formatted(date: .abbreviated, time: .standard)
            let details = (entry.details?.isEmpty == false) ? " — \(entry.details ?? "")" : ""
            return "[\(timestamp)] \(entry.category.title): \(entry.message)\(details)"
        }
        return ([header, ""] + lines).joined(separator: "\n")
    }

    @ViewBuilder
    private var emptyState: some View {
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: search)
        } else if entries.isEmpty {
            ContentUnavailableView(
                "No Activity Yet",
                systemImage: "clock",
                description: Text("Applied changes, connection problems, and local API events show up here.")
            )
        } else {
            ContentUnavailableView(
                "Nothing in \(selectedCategory.title)",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Choose another category from the menu.")
            )
        }
    }

    private func row(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: entry.category.symbolName)
                    .font(.caption)
                    .foregroundStyle(entry.category.color)
                    .accessibilityHidden(true)
                Text(entry.message)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let details = entry.details, !details.isEmpty {
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
