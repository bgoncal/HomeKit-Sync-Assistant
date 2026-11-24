import SwiftUI

/// The devices in one Apple Home, grouped by room.
struct HomeDevicesView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var connections: ConnectionStore
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var preferences: SyncPreferencesStore

    let homeId: String

    @State private var search = ""

    private var home: HomeSummary? { homeKitManager.home(byId: homeId) }

    var body: some View {
        HomeDevicesContent(
            home: home,
            search: $search,
            excludedAccessoryIds: preferences.excludedAccessoryIds,
            excludedRoomNames: preferences.excludedRoomNames(homeId: homeId),
            manualEntityIds: manualEntityIds,
            onSetAccessoryExcluded: { preferences.setAccessoryExcluded($1, accessoryId: $0) },
            onSetRoomExcluded: { preferences.setRoomExcluded($1, homeId: homeId, roomName: $0) }
        )
            // Serial numbers are what pair a device with Home Assistant, so read them
            // once the list is on screen rather than only inside a sync.
            .task(id: homeId) {
                await homeKitManager.refreshSerialNumbers(forHomeId: homeId)
            }
            .navigationDestination(for: String.self) { accessoryId in
                if let accessory = homeKitManager.accessory(byId: accessoryId) {
                    DeviceDetailView(
                        accessory: accessory,
                        homeId: homeId,
                        server: connections.suggestedServer(forHomeId: homeId)
                    )
                    .environmentObject(homeKitManager)
                    .environmentObject(syncEngine)
                    .environmentObject(preferences)
                } else {
                    ContentUnavailableView(
                        "Device Not Found",
                        systemImage: "questionmark.circle",
                        description: Text("It may have been removed from Apple Home since this list was loaded.")
                    )
                }
            }
    }

    private var manualEntityIds: [String: String] {
        var result: [String: String] = [:]
        for accessory in home?.accessories ?? [] {
            if let entityId = preferences.manualEntityId(forAccessoryId: accessory.id) {
                result[accessory.id] = entityId
            }
        }
        return result
    }
}

struct HomeDevicesContent: View {
    let home: HomeSummary?
    @Binding var search: String
    var excludedAccessoryIds: Set<String> = []
    /// Lowercased room names every sync leaves alone.
    var excludedRoomNames: Set<String> = []
    /// Entities picked by hand, by accessory ID.
    var manualEntityIds: [String: String] = [:]
    var onSetAccessoryExcluded: (String, Bool) -> Void = { _, _ in }
    var onSetRoomExcluded: (String, Bool) -> Void = { _, _ in }

    /// Devices by room, in the order Apple Home lists the rooms, with anything
    /// unassigned last.
    private var rooms: [(name: String, accessories: [AccessorySummary])] {
        guard let home else { return [] }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = home.accessories.filter { accessory in
            guard !query.isEmpty else { return true }
            return accessory.name.localizedCaseInsensitiveContains(query)
                || accessory.roomName.localizedCaseInsensitiveContains(query)
                || (accessory.serialNumber?.localizedCaseInsensitiveContains(query) ?? false)
        }

        var byRoom: [String: [AccessorySummary]] = [:]
        for accessory in matching {
            byRoom[accessory.roomName, default: []].append(accessory)
        }

        let ordered = home.rooms.map(\.name) + [RoomSummary.defaultRoomName]
        var result: [(String, [AccessorySummary])] = []
        for name in ordered {
            if let accessories = byRoom.removeValue(forKey: name), !accessories.isEmpty {
                result.append((name, accessories))
            }
        }
        for (name, accessories) in byRoom.sorted(by: { $0.key < $1.key }) {
            result.append((name, accessories))
        }
        return result
    }

    private var deviceCount: Int {
        rooms.reduce(0) { $0 + $1.accessories.count }
    }

    var body: some View {
        List {
            ForEach(rooms, id: \.name) { room in
                let isRoomExcluded = excludedRoomNames.contains(room.name.lowercased())
                Section {
                    ForEach(room.accessories) { accessory in
                        NavigationLink(value: accessory.id) {
                            row(for: accessory, isRoomExcluded: isRoomExcluded)
                        }
                        .contextMenu {
                            menu(for: accessory, roomName: room.name, isRoomExcluded: isRoomExcluded)
                        }
                    }
                } header: {
                    Text(isRoomExcluded ? "\(room.name) · Excluded from Syncs" : room.name)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Search name or entity ID")
        .overlay {
            if rooms.isEmpty {
                emptyState
            }
        }
        .navigationTitle(home?.name ?? SyncPlatform.appleHome.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            ContentUnavailableView(
                "No Devices",
                systemImage: "sensor",
                description: Text("Add devices in the Apple Home app, or pick another home.")
            )
        }
    }

    @ViewBuilder
    private func menu(for accessory: AccessorySummary, roomName: String, isRoomExcluded: Bool) -> some View {
        if excludedAccessoryIds.contains(accessory.id) {
            Button("Include in Syncs", systemImage: "plus.circle") {
                onSetAccessoryExcluded(accessory.id, false)
            }
        } else {
            Button("Exclude from Syncs", systemImage: "minus.circle") {
                onSetAccessoryExcluded(accessory.id, true)
            }
        }

        if roomName != RoomSummary.defaultRoomName {
            if isRoomExcluded {
                Button("Include “\(roomName)” in Syncs", systemImage: "plus.square") {
                    onSetRoomExcluded(roomName, false)
                }
            } else {
                Button("Exclude “\(roomName)” from Syncs", systemImage: "minus.square") {
                    onSetRoomExcluded(roomName, true)
                }
            }
        }
    }

    private func row(for accessory: AccessorySummary, isRoomExcluded: Bool) -> some View {
        let isExcluded = isRoomExcluded || excludedAccessoryIds.contains(accessory.id)
        let entityId = manualEntityIds[accessory.id] ?? accessory.entityId
        return HStack(spacing: 12) {
            Image(systemName: accessory.isReachable ? "sensor.fill" : "sensor")
                .font(.title3)
                .foregroundStyle(accessory.isReachable ? Color.accentColor : Color.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(accessory.name)
                if let entityId {
                    Text(entityId)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let model = accessory.model, !model.isEmpty {
                    Text(model)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isExcluded {
                BridgePill(title: "Excluded", systemImage: "minus.circle", tint: .secondary)
            } else if entityId != nil {
                BridgePill(title: "Bridged", systemImage: "link", tint: .green)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail

/// What the bridge knows about one device's Home Assistant counterpart.
enum DeviceMatchState: Equatable {
    case loading
    case matched(HomeAssistantMatch)
    case notBridged
    case noEntity
    /// The home this device is in has no Home Assistant server linked yet.
    case noServer
    case failed(String)
}

private struct DeviceDetailView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var preferences: SyncPreferencesStore

    let accessory: AccessorySummary
    let homeId: String
    /// The Home Assistant to ask about this device — the one last used with this home.
    let server: HomeAssistantServer?

    @State private var matchState: DeviceMatchState = .loading
    @State private var resolvedAccessory: AccessorySummary?
    @State private var isPickingEntity = false

    private var current: AccessorySummary { resolvedAccessory ?? accessory }
    private var manualEntityId: String? { preferences.manualEntityId(forAccessoryId: accessory.id) }

    var body: some View {
        DeviceDetailContent(
            accessory: current,
            matchState: matchState,
            serverName: server?.name,
            isExcluded: preferences.isAccessoryExcluded(accessory.id),
            isRoomExcluded: preferences.isRoomExcluded(homeId: homeId, roomName: current.roomName),
            isPairedByHand: manualEntityId != nil,
            onSetExcluded: { preferences.setAccessoryExcluded($0, accessoryId: accessory.id) },
            onChooseEntity: server == nil ? nil : { isPickingEntity = true },
            onUseAutomaticPairing: {
                preferences.setManualEntityId(nil, forAccessoryId: accessory.id)
                Task { await loadMatch() }
            }
        )
        .task(id: accessory.id) {
            await loadMatch()
        }
        .sheet(isPresented: $isPickingEntity) {
            if let server {
                NavigationStack {
                    EntityPickerView(
                        serverId: server.id,
                        deviceName: current.name,
                        selectedEntityId: manualEntityId ?? current.entityId,
                        onPick: { entityId in
                            preferences.setManualEntityId(entityId, forAccessoryId: accessory.id)
                            Task { await loadMatch() }
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { isPickingEntity = false }
                        }
                    }
                }
            }
        }
    }

    private func loadMatch() async {
        matchState = .loading

        let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id)
        resolvedAccessory = homeKitManager.accessory(byId: accessory.id) ?? accessory

        // A pairing made by hand wins over whatever the serial number says.
        guard let entityId = manualEntityId ?? serial, !entityId.isEmpty else {
            matchState = .notBridged
            return
        }

        guard let server else {
            matchState = .noServer
            return
        }

        do {
            if let match = try await syncEngine.homeAssistantMatch(forEntityId: entityId, homeId: homeId, serverId: server.id) {
                matchState = .matched(match)
            } else {
                matchState = .noEntity
            }
        } catch {
            matchState = .failed(error.localizedDescription)
        }
    }
}

struct DeviceDetailContent: View {
    let accessory: AccessorySummary
    let matchState: DeviceMatchState
    /// The Home Assistant paired with this device's home, when there is one.
    var serverName: String?
    var isExcluded: Bool = false
    /// The whole room is left out, which overrides the device's own switch.
    var isRoomExcluded: Bool = false
    var isPairedByHand: Bool = false
    var onSetExcluded: (Bool) -> Void = { _ in }
    /// `nil` when there is no server to pick from.
    var onChooseEntity: (() -> Void)?
    var onUseAutomaticPairing: () -> Void = {}

    var body: some View {
        List {
            Section {
                BridgeStatusRow(
                    title: accessory.isReachable ? "Reachable" : "Not Reachable",
                    message: accessory.isReachable
                        ? "Apple Home can talk to this device right now."
                        : "Renaming or moving it may fail until it is back.",
                    systemImage: accessory.isReachable ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    tint: accessory.isReachable ? .green : .orange
                )
            }

            homeAssistantSection
            syncingSection

            Section {
                LabeledContent("Room", value: accessory.roomName)
                LabeledContent("Type", value: accessory.category)
                LabeledContent("Manufacturer", value: accessory.manufacturer ?? "Unavailable")
                LabeledContent("Model", value: accessory.model ?? "Unavailable")
                LabeledContent("Serial Number", value: accessory.serialNumber ?? "Unavailable")
                    .lineLimit(1)
                    .truncationMode(.middle)
            } header: {
                Text(SyncPlatform.appleHome.name)
            } footer: {
                Text("\(serverName ?? SyncPlatform.homeAssistant.name) writes the entity ID into the serial number, which is how the bridge pairs the two sides.")
            }

            if !accessory.services.isEmpty {
                Section {
                    NavigationLink {
                        DeviceServicesContent(accessory: accessory)
                    } label: {
                        LabeledContent("HomeKit Services", value: accessory.services.count.formatted())
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(accessory.name)
    }

    // MARK: Syncing

    private var syncingSection: some View {
        Section {
            Toggle("Include in Syncs", isOn: Binding(
                get: { !isExcluded && !isRoomExcluded },
                set: { onSetExcluded(!$0) }
            ))
            .disabled(isRoomExcluded)
        } footer: {
            if isRoomExcluded {
                Text("Every device in “\(accessory.roomName)” is left out. Include the room again from the device list.")
            } else if isExcluded {
                Text("Every sync leaves this device alone: its name and room stay as they are on both sides.")
            } else {
                Text("Turn off to keep this device's name and room exactly as they are, whatever a sync would change.")
            }
        }
    }

    @ViewBuilder
    private var chooseEntityButton: some View {
        if let onChooseEntity {
            Button(isPairedByHand ? "Choose Another Entity…" : "Choose Entity…", action: onChooseEntity)
        }
    }

    @ViewBuilder
    private var homeAssistantSection: some View {
        switch matchState {
        case .loading:
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Checking Home Assistant…")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(homeAssistantSectionTitle)
            }

        case .matched(let match):
            Section {
                BridgeStatusRow(
                    title: "Paired",
                    message: match.areaName.map { "This device syncs in both directions. In \(match.serverName) it sits in “\($0)”." }
                        ?? "This device syncs in both directions. It has no area in \(match.serverName) yet.",
                    systemImage: "link.circle.fill",
                    tint: .green
                )
                LabeledContent("Entity ID", value: match.entityId)
                    .lineLimit(1)
                    .truncationMode(.middle)
                LabeledContent("Name", value: match.friendlyName ?? "Unnamed")
                LabeledContent("Area", value: match.areaName ?? "None")
                if isPairedByHand {
                    LabeledContent("Paired", value: "By Hand")
                }
                NavigationLink {
                    HomeAssistantDataContent(match: match)
                } label: {
                    Text("Raw Data")
                }
                chooseEntityButton
                if isPairedByHand {
                    Button("Use Automatic Pairing", action: onUseAutomaticPairing)
                }
            } header: {
                Text(match.serverName)
            } footer: {
                if isPairedByHand {
                    Text("Paired by hand. Automatic pairing reads the entity ID from the serial number instead.")
                }
            }

        case .notBridged:
            Section {
                BridgeStatusRow(
                    title: "Not Bridged",
                    message: "This device has no entity ID in its serial number, so every sync skips it and leaves it untouched.",
                    systemImage: "link.badge.plus",
                    tint: .orange
                )
                chooseEntityButton
            } header: {
                Text(homeAssistantSectionTitle)
            } footer: {
                Text("Expose it through Home Assistant's HomeKit Bridge integration, or choose its entity by hand.")
            }

        case .noEntity:
            Section {
                BridgeStatusRow(
                    title: "No Matching Entity",
                    message: "“\(accessory.serialNumber ?? "")” does not match any entity ID in \(homeAssistantSectionTitle). It may have been renamed or removed there.",
                    systemImage: "questionmark.circle.fill",
                    tint: .orange
                )
                chooseEntityButton
            } header: {
                Text(homeAssistantSectionTitle)
            }

        case .noServer:
            Section {
                BridgeStatusRow(
                    title: "No Server Linked",
                    message: "No Home Assistant has been used with this home yet, so there is nothing to compare it against.",
                    systemImage: "link.badge.plus",
                    tint: .orange
                )
            } header: {
                Text(SyncPlatform.homeAssistant.name)
            } footer: {
                Text("Run a sync for this home once, and this page will use the same server.")
            }

        case .failed(let message):
            Section {
                BridgeStatusRow(
                    title: "Could Not Check",
                    message: message,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red
                )
            } header: {
                Text(homeAssistantSectionTitle)
            }
        }
    }

    private var homeAssistantSectionTitle: String {
        serverName ?? SyncPlatform.homeAssistant.name
    }
}

/// Every HomeKit service on one device, and what each characteristic reads.
struct DeviceServicesContent: View {
    let accessory: AccessorySummary

    var body: some View {
        List {
            ForEach(accessory.services) { service in
                Section {
                    ForEach(service.characteristics) { characteristic in
                        LabeledContent {
                            Text(characteristic.value)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Text(shortName(characteristic.type))
                                .font(.callout)
                        }
                    }
                } header: {
                    Text(service.name)
                } footer: {
                    Text(service.type)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Services")
    }

    /// HomeKit types read as reverse-DNS strings; the last component is the part
    /// worth putting in a row label.
    private func shortName(_ type: String) -> String {
        type.split(separator: ".").last.map(String.init)?.capitalized ?? type
    }
}

/// The registry payloads behind a match, for when something does not line up.
struct HomeAssistantDataContent: View {
    let match: HomeAssistantMatch

    var body: some View {
        List {
            if let deviceId = match.deviceId {
                Section {
                    LabeledContent("Device ID", value: deviceId)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            section("State", json: match.stateJSON)
            section("Entity Registry", json: match.entityJSON)
            if let deviceJSON = match.deviceJSON {
                section("Device Registry", json: deviceJSON)
            }
            if let areaJSON = match.areaJSON {
                section("Area Registry", json: areaJSON)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Raw Data")
    }

    private func section(_ title: String, json: String) -> some View {
        Section {
            BridgeCodeBlock(content: json)
        } header: {
            Text(title)
        }
    }
}
