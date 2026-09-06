import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine

    @State private var path: [String] = []
    @State private var search = ""

    var body: some View {
        NavigationStack(path: $path) {
            DevicesContent(
                homes: homeKitManager.homes,
                selectedHomeId: homeKitManager.selectedHome?.id,
                search: $search,
                onSelectHome: { homeId in
                    homeKitManager.selectHome(id: homeId)
                    path.removeAll()
                }
            )
            .navigationDestination(for: String.self) { accessoryId in
                if let accessory = homeKitManager.accessory(byId: accessoryId) {
                    DeviceDetailView(accessory: accessory)
                        .environmentObject(homeKitManager)
                        .environmentObject(syncEngine)
                } else {
                    ContentUnavailableView(
                        "Device Not Found",
                        systemImage: "questionmark.circle",
                        description: Text("It may have been removed from Apple Home since this list was loaded.")
                    )
                }
            }
        }
        // Serial numbers are what pairs a device with Home Assistant, so read
        // them once the list is on screen instead of only inside a sync.
        .task(id: homeKitManager.selectedHome?.id) {
            guard let homeId = homeKitManager.selectedHome?.id else { return }
            await homeKitManager.refreshSerialNumbers(forHomeId: homeId)
        }
    }
}

/// The device list for one Apple Home.
struct DevicesContent: View {
    let homes: [HomeSummary]
    let selectedHomeId: String?
    @Binding var search: String
    var onSelectHome: (String) -> Void = { _ in }

    private var selectedHome: HomeSummary? {
        guard let selectedHomeId else { return homes.first }
        return homes.first { $0.id == selectedHomeId } ?? homes.first
    }

    private var accessories: [AccessorySummary] {
        let all = selectedHome?.accessories ?? []
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.roomName.localizedCaseInsensitiveContains(query)
                || ($0.serialNumber?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        List {
            if homes.count > 1 {
                Section {
                    Picker("Home", selection: Binding(
                        get: { selectedHome?.id ?? "" },
                        set: { onSelectHome($0) }
                    )) {
                        ForEach(homes) { home in
                            Text(home.name).tag(home.id)
                        }
                    }
                }
            }

            if !accessories.isEmpty {
                Section {
                    ForEach(accessories) { accessory in
                        NavigationLink(value: accessory.id) {
                            row(for: accessory)
                        }
                    }
                } header: {
                    Text("\(accessories.count) Device\(accessories.count == 1 ? "" : "s")")
                } footer: {
                    Text("Devices bridged from Home Assistant can be synced. Everything else is listed but skipped.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Search devices")
        .overlay {
            if accessories.isEmpty {
                emptyState
            }
        }
        .navigationTitle(selectedHome?.name ?? "Devices")
    }

    @ViewBuilder
    private var emptyState: some View {
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: search)
        } else if homes.isEmpty {
            ContentUnavailableView(
                "No Apple Home Yet",
                systemImage: "house",
                description: Text("Allow access on the Dashboard, then come back.")
            )
        } else {
            ContentUnavailableView(
                "No Devices",
                systemImage: "sensor",
                description: Text("Add devices in the Apple Home app, or pick another home.")
            )
        }
    }

    private func row(for accessory: AccessorySummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: accessory.isReachable ? "sensor.fill" : "sensor")
                .font(.title3)
                .foregroundStyle(accessory.isReachable ? Color.accentColor : Color.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(accessory.name)
                Text(subtitle(for: accessory))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if accessory.entityId != nil {
                BridgePill(title: "Bridged", systemImage: "link", tint: .green)
            }
        }
        .padding(.vertical, 2)
    }

    private func subtitle(for accessory: AccessorySummary) -> String {
        [accessory.roomName, accessory.model]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

// MARK: - Detail

/// What the bridge knows about one device's Home Assistant counterpart.
enum DeviceMatchState: Equatable {
    case loading
    case matched(HomeAssistantMatch)
    case notBridged
    case noEntity
    case failed(String)
}

private struct DeviceDetailView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine

    let accessory: AccessorySummary

    @State private var matchState: DeviceMatchState = .loading
    @State private var resolvedAccessory: AccessorySummary?

    var body: some View {
        DeviceDetailContent(
            accessory: resolvedAccessory ?? accessory,
            matchState: matchState
        )
        .task(id: accessory.id) {
            await loadMatch()
        }
    }

    private func loadMatch() async {
        matchState = .loading

        let serial = await homeKitManager.refreshSerialNumber(accessoryId: accessory.id)
        resolvedAccessory = homeKitManager.accessory(byId: accessory.id) ?? accessory

        guard let serial, !serial.isEmpty else {
            matchState = .notBridged
            return
        }

        do {
            if let match = try await syncEngine.homeAssistantMatch(forEntityId: serial) {
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
                Text("Home Assistant writes the entity ID into the serial number, which is how the bridge pairs the two sides.")
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
                Text(SyncPlatform.homeAssistant.name)
            }

        case .matched(let match):
            Section {
                BridgeStatusRow(
                    title: "Paired",
                    message: match.areaName.map { "This device syncs in both directions. In Home Assistant it sits in “\($0)”." }
                        ?? "This device syncs in both directions. It has no Home Assistant area yet.",
                    systemImage: "link.circle.fill",
                    tint: .green
                )
                LabeledContent("Entity ID", value: match.entityId)
                    .lineLimit(1)
                    .truncationMode(.middle)
                LabeledContent("Name", value: match.friendlyName ?? "Unnamed")
                LabeledContent("Area", value: match.areaName ?? "None")
                NavigationLink {
                    HomeAssistantDataContent(match: match)
                } label: {
                    Text("Raw Data")
                }
            } header: {
                Text(SyncPlatform.homeAssistant.name)
            }

        case .notBridged:
            Section {
                BridgeStatusRow(
                    title: "Not Bridged",
                    message: "This device has no entity ID in its serial number, so every sync skips it and leaves it untouched.",
                    systemImage: "link.badge.plus",
                    tint: .orange
                )
            } header: {
                Text(SyncPlatform.homeAssistant.name)
            } footer: {
                Text("Expose it through Home Assistant's HomeKit Bridge integration to sync it.")
            }

        case .noEntity:
            Section {
                BridgeStatusRow(
                    title: "No Matching Entity",
                    message: "“\(accessory.serialNumber ?? "")” does not match any Home Assistant entity ID. It may have been renamed or removed there.",
                    systemImage: "questionmark.circle.fill",
                    tint: .orange
                )
            } header: {
                Text(SyncPlatform.homeAssistant.name)
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
                Text(SyncPlatform.homeAssistant.name)
            }
        }
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
