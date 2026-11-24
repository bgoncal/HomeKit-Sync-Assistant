import SwiftUI

/// One device or room every sync leaves alone.
struct ExclusionItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case device(accessoryId: String)
        case room(homeId: String, roomName: String)
    }

    let id: String
    let kind: Kind
    let title: String
    /// The home it belongs to.
    let subtitle: String
}

/// Everything left out of syncs, gathered in one place so it is easy to undo.
struct ExclusionsView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var preferences: SyncPreferencesStore

    var body: some View {
        ExclusionsContent(items: items) { item in
            switch item.kind {
            case .device(let accessoryId):
                preferences.setAccessoryExcluded(false, accessoryId: accessoryId)
            case .room(let homeId, let roomName):
                preferences.setRoomExcluded(false, homeId: homeId, roomName: roomName)
            }
        }
    }

    private var items: [ExclusionItem] {
        var result: [ExclusionItem] = []
        for home in homeKitManager.homes {
            for roomName in preferences.excludedRoomNames(homeId: home.id).sorted() {
                let name = home.room(named: roomName)?.name ?? roomName
                result.append(ExclusionItem(
                    id: "room|\(home.id)|\(roomName)",
                    kind: .room(homeId: home.id, roomName: name),
                    title: name,
                    subtitle: home.name
                ))
            }
            for accessory in home.accessories where preferences.isAccessoryExcluded(accessory.id) {
                result.append(ExclusionItem(
                    id: "device|\(accessory.id)",
                    kind: .device(accessoryId: accessory.id),
                    title: accessory.name,
                    subtitle: "\(home.name) · \(accessory.roomName)"
                ))
            }
        }
        return result
    }
}

struct ExclusionsContent: View {
    let items: [ExclusionItem]
    var onInclude: (ExclusionItem) -> Void = { _ in }

    private var rooms: [ExclusionItem] {
        items.filter { if case .room = $0.kind { return true } else { return false } }
    }

    private var devices: [ExclusionItem] {
        items.filter { if case .device = $0.kind { return true } else { return false } }
    }

    var body: some View {
        List {
            if !rooms.isEmpty {
                Section {
                    ForEach(rooms) { row($0, systemImage: "square.split.bottomrightquarter") }
                } header: {
                    Text("Rooms")
                } footer: {
                    Text("Nothing in these rooms is renamed or moved, and no area is created for them.")
                }
            }

            if !devices.isEmpty {
                Section {
                    ForEach(devices) { row($0, systemImage: "sensor") }
                } header: {
                    Text("Devices")
                } footer: {
                    Text("These keep their name and room on both sides, whatever a sync would change.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(
                    "Nothing Excluded",
                    systemImage: "minus.circle",
                    description: Text("Press and hold a device or room in an Apple Home's device list to leave it out of every sync.")
                )
            }
        }
        .navigationTitle("Excluded from Syncs")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ item: ExclusionItem, systemImage: String) -> some View {
        Label {
            Text(item.title)
            Text(item.subtitle)
        } icon: {
            Image(systemName: systemImage)
        }
        .swipeActions(edge: .trailing) {
            Button("Include", systemImage: "plus.circle") { onInclude(item) }
                .tint(.green)
        }
        .contextMenu {
            Button("Include in Syncs", systemImage: "plus.circle") { onInclude(item) }
        }
    }
}
