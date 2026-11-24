import SwiftUI

/// Pick the Home Assistant entity an Apple Home device stands for, when its serial
/// number does not say.
struct EntityPickerView: View {
    @EnvironmentObject private var connections: ConnectionStore
    @EnvironmentObject private var syncEngine: SyncEngine
    @Environment(\.dismiss) private var dismiss

    let serverId: UUID
    let deviceName: String
    let selectedEntityId: String?
    var onPick: (String) -> Void

    @State private var areas: [EntityArea] = []
    @State private var search = ""
    @State private var loadState: EntityLoadState = .loading

    var body: some View {
        EntityPickerContent(
            serverName: connections.server(id: serverId)?.name ?? SyncPlatform.homeAssistant.name,
            deviceName: deviceName,
            areas: areas,
            state: loadState,
            selectedEntityId: selectedEntityId,
            search: $search,
            onPick: { entityId in
                onPick(entityId)
                dismiss()
            }
        )
        .task(id: serverId) {
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
}

struct EntityPickerContent: View {
    let serverName: String
    let deviceName: String
    let areas: [EntityArea]
    var state: EntityLoadState = .loaded
    var selectedEntityId: String?
    @Binding var search: String
    var onPick: (String) -> Void = { _ in }

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

    var body: some View {
        List {
            ForEach(filtered) { area in
                Section {
                    ForEach(area.entities) { entity in
                        Button {
                            onPick(entity.entityId)
                        } label: {
                            LabeledContent {
                                if entity.entityId == selectedEntityId {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.blue)
                                        .accessibilityLabel("Selected")
                                }
                            } label: {
                                Text(entity.name)
                                Text(entity.entityId)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                        // A choice in a list, as in Settings: black text, a checkmark for the pick.
                        .tint(.primary)
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
                ContentUnavailableView("Reading \(serverName)…", systemImage: "arrow.triangle.2.circlepath")
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
                            description: Text("\(serverName) reported nothing to pair with.")
                        )
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
        }
        .navigationTitle("Pair “\(deviceName)”")
        .navigationBarTitleDisplayMode(.inline)
    }
}
