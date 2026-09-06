import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var syncEngine: SyncEngine

    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            DevicesContent(
                homes: homeKitManager.homes,
                selectedHomeId: homeKitManager.selectedHome?.id,
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
                        "Device not found",
                        systemImage: "questionmark.circle",
                        description: Text("It may have been removed from Apple Home since this list was loaded.")
                    )
                }
            }
        }
    }
}

/// The device list for one Apple Home.
struct DevicesContent: View {
    let homes: [HomeSummary]
    let selectedHomeId: String?
    var onSelectHome: (String) -> Void = { _ in }

    private var selectedHome: HomeSummary? {
        guard let selectedHomeId else { return homes.first }
        return homes.first { $0.id == selectedHomeId } ?? homes.first
    }

    var body: some View {
        BridgePage(
            title: "Devices",
            subtitle: "Every Apple Home device, and whether the bridge can pair it with a Home Assistant entity."
        ) {
            homePicker

            if let selectedHome, !selectedHome.accessories.isEmpty {
                LazyVStack(spacing: 10) {
                    ForEach(selectedHome.accessories) { accessory in
                        NavigationLink(value: accessory.id) {
                            BridgeCard {
                                accessoryRow(accessory)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                BridgeCard {
                    ContentUnavailableView(
                        homes.isEmpty ? "No Apple Home yet" : "No devices in this home",
                        systemImage: "house",
                        description: Text(homes.isEmpty
                            ? "Grant HomeKit access on the Dashboard, then come back."
                            : "Add devices in the Apple Home app, or pick another home above.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        }
    }

    private var homePicker: some View {
        BridgeCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Apple Home")
                    .font(.headline)

                Picker("Apple Home", selection: Binding(
                    get: { selectedHome?.id ?? "" },
                    set: { onSelectHome($0) }
                )) {
                    if homes.isEmpty {
                        Text("No Apple homes found").tag("")
                    } else {
                        ForEach(homes) { home in
                            Text(home.name).tag(home.id)
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(homes.isEmpty)
            }
        }
    }

    private func accessoryRow(_ accessory: AccessorySummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sensor.tag.radiowaves.forward")
                .foregroundStyle(accessory.isReachable ? Color.blue : Color.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(accessory.name)
                    .font(.headline)
                Text(subtitle(for: accessory))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
        }
    }

    private func subtitle(for accessory: AccessorySummary) -> String {
        [accessory.roomName, accessory.manufacturer, accessory.model]
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
        BridgePage(title: accessory.name, subtitle: accessory.roomName) {
            reachabilityCard
            matchCard
            appleHomeDetailsCard
            servicesCard
        }
    }

    private var reachabilityCard: some View {
        BridgeCard {
            BridgeStatusHeader(
                title: accessory.isReachable ? "Reachable" : "Not reachable",
                message: accessory.isReachable
                    ? "Apple Home can talk to this device right now."
                    : "Apple Home cannot reach this device. Renaming and moving it may fail until it is back.",
                systemImage: accessory.isReachable ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                tint: accessory.isReachable ? .green : .orange
            )

            VStack(spacing: 8) {
                BridgeInfoRow(label: "Manufacturer", value: accessory.manufacturer ?? "Unavailable")
                BridgeInfoRow(label: "Model", value: accessory.model ?? "Unavailable")
                BridgeInfoRow(label: "Type", value: accessory.category)
                BridgeInfoRow(label: "Serial number", value: accessory.serialNumber ?? "Unavailable", selectable: true)
            }
        }
    }

    @ViewBuilder
    private var matchCard: some View {
        switch matchState {
        case .loading:
            BridgeCard {
                BridgeStatusHeader(
                    title: "Looking for a match",
                    message: "Reading the serial number and checking it against Home Assistant entity IDs.",
                    systemImage: "magnifyingglass.circle.fill",
                    tint: .blue
                )
            }

        case .matched(let match):
            BridgeCard {
                BridgeStatusHeader(
                    title: "Paired with Home Assistant",
                    message: match.areaName.map { "This device syncs in both directions. In Home Assistant it sits in “\($0)”." }
                        ?? "This device syncs in both directions. It has no Home Assistant area yet.",
                    systemImage: "link.circle.fill",
                    tint: .green
                )

                VStack(spacing: 8) {
                    BridgeInfoRow(label: "Entity ID", value: match.entityId, selectable: true)
                    BridgeInfoRow(label: "Home Assistant name", value: match.friendlyName ?? "Unnamed")
                    BridgeInfoRow(label: "Home Assistant area", value: match.areaName ?? "None")
                    BridgeInfoRow(label: "Apple Home room", value: accessory.roomName)
                }

                DisclosureGroup("Raw Home Assistant data") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let deviceId = match.deviceId {
                            BridgeInfoRow(label: "Device ID", value: deviceId, selectable: true)
                        }
                        jsonSection(title: "State", json: match.stateJSON)
                        jsonSection(title: "Entity registry", json: match.entityJSON)
                        if let deviceJSON = match.deviceJSON {
                            jsonSection(title: "Device registry", json: deviceJSON)
                        }
                        if let areaJSON = match.areaJSON {
                            jsonSection(title: "Area registry", json: areaJSON)
                        }
                    }
                    .padding(.top, 8)
                }
            }

        case .notBridged:
            BridgeCard {
                BridgeStatusHeader(
                    title: "Not bridged from Home Assistant",
                    message: "This device has no entity ID in its serial number, so the bridge cannot pair it. Every sync skips it and leaves it untouched.",
                    systemImage: "link.badge.plus",
                    tint: .orange
                )
            }

        case .noEntity:
            BridgeCard {
                BridgeStatusHeader(
                    title: "No matching entity in Home Assistant",
                    message: "The serial number “\(accessory.serialNumber ?? "")” does not match any Home Assistant entity ID. It may have been renamed or removed there.",
                    systemImage: "questionmark.circle.fill",
                    tint: .orange
                )
            }

        case .failed(let message):
            BridgeCard {
                BridgeStatusHeader(
                    title: "Could not check Home Assistant",
                    message: message,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red
                )
            }
        }
    }

    private var appleHomeDetailsCard: some View {
        BridgeCard {
            DisclosureGroup("Apple Home details") {
                VStack(spacing: 8) {
                    BridgeInfoRow(label: "Name", value: accessory.name)
                    BridgeInfoRow(label: "Identifier", value: accessory.id, selectable: true)
                    BridgeInfoRow(label: "Room", value: accessory.roomName)
                    BridgeInfoRow(label: "Reachable", value: accessory.isReachable ? "Yes" : "No")
                    BridgeInfoRow(label: "Blocked", value: accessory.isBlocked ? "Yes" : "No")
                    BridgeInfoRow(label: "Bridged", value: accessory.isBridged ? "Yes" : "No")
                }
                .padding(.top, 8)
            }
        }
    }

    private var servicesCard: some View {
        BridgeCard {
            DisclosureGroup("HomeKit services") {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(accessory.services) { service in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(service.name)
                                .font(.headline)
                            Text(service.type)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            ForEach(service.characteristics) { characteristic in
                                LabeledContent {
                                    Text(characteristic.value)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                        .multilineTextAlignment(.trailing)
                                } label: {
                                    Text(characteristic.type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func jsonSection(title: String, json: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            BridgeCodeBlock(content: json)
        }
    }
}
