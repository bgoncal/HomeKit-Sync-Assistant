import SwiftUI

/// Everything one Home Assistant exposes, grouped by area.
struct EntitiesView: View {
    @EnvironmentObject private var connections: ConnectionStore
    @EnvironmentObject private var syncEngine: SyncEngine

    let serverId: UUID

    @State private var areas: [EntityArea] = []
    @State private var search = ""
    @State private var loadState: EntityLoadState = .loading

    var body: some View {
        EntitiesContent(
            serverName: connections.server(id: serverId)?.name ?? SyncPlatform.homeAssistant.name,
            serverId: serverId,
            areas: areas,
            state: loadState,
            search: $search
        )
        .task(id: serverId) {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        loadState = .loading
        do {
            areas = try await syncEngine.entities(forServerId: serverId)
            loadState = .loaded
        } catch {
            areas = []
            loadState = .failed(error.localizedDescription)
        }
    }
}

enum EntityLoadState: Equatable {
    case loading
    case loaded
    case failed(String)
}

struct EntitiesContent: View {
    let serverName: String
    var serverId: UUID?
    let areas: [EntityArea]
    var state: EntityLoadState = .loaded
    @Binding var search: String

    private var filtered: [EntityArea] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return areas }

        return areas.compactMap { area in
            let matches = area.entities.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.entityId.localizedCaseInsensitiveContains(query)
            }
            return matches.isEmpty ? nil : EntityArea(name: area.name, entities: matches)
        }
    }

    private var entityCount: Int {
        filtered.reduce(0) { $0 + $1.entities.count }
    }

    var body: some View {
        List {
            ForEach(filtered) { area in
                Section {
                    ForEach(area.entities) { entity in
                        row(entity)
                    }
                } header: {
                    Text(area.name)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Search name or entity ID")
        .overlay {
            switch state {
            case .loading where areas.isEmpty:
                ProgressView("Reading \(serverName)…")
            case .failed(let message):
                ContentUnavailableView(
                    "Could Not Read \(serverName)",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            default:
                if filtered.isEmpty {
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView(
                            "No Entities",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("\(serverName) reported nothing to show.")
                        )
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
        }
        .navigationTitle(serverName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let serverId {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: HomeRoute.serverSettings(serverId)) {
                        Label("Server Settings", systemImage: "gearshape")
                    }
                }
            }
        }
        .navigationSubtitle(entityCount == 0 ? "" : "\(entityCount) entit\(entityCount == 1 ? "y" : "ies")")
    }

    private func row(_ entity: EntitySummary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entity.name)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(entity.state)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(entity.entityId)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    /// `navigationSubtitle` only exists on some platforms; this keeps call sites tidy.
    @ViewBuilder
    func navigationSubtitle(_ subtitle: String) -> some View {
        self
    }
}
