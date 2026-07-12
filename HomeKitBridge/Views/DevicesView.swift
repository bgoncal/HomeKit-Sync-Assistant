import HomeKit
import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var wsClient: HAWebSocketClient

    @State private var selectedHomeId = ""
    @State private var path: [String] = []

    private var selectedHome: HMHome? {
        if let home = homeKitManager.home(byId: selectedHomeId) {
            return home
        }
        return homeKitManager.primaryHome
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Browse Apple Home accessories and check how they match Home Assistant.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                homePicker

                if let selectedHome {
                    List(selectedHome.accessories, id: \.uniqueIdentifier) { accessory in
                        NavigationLink(value: accessory.uniqueIdentifier.uuidString) {
                            accessoryRow(accessory)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Spacer()
                    ContentUnavailableView("No Apple Home Selected", systemImage: "house", description: Text("Choose an Apple Home to list its devices."))
                    Spacer()
                }
            }
            .padding(20)
            .navigationTitle("Devices")
            .navigationDestination(for: String.self) { accessoryId in
                if let accessory = homeKitManager.accessory(byId: accessoryId) {
                    DeviceDetailView(accessory: accessory)
                        .environmentObject(homeKitManager)
                        .environmentObject(wsClient)
                } else {
                    ContentUnavailableView("Device Not Found", systemImage: "questionmark.circle")
                }
            }
        }
        .onAppear {
            if selectedHomeId.isEmpty {
                selectedHomeId = homeKitManager.primaryHome?.uniqueIdentifier.uuidString ?? ""
            }
        }
        .onChange(of: homeKitManager.selectedHomeId) { _, newValue in
            if selectedHomeId.isEmpty {
                selectedHomeId = newValue ?? ""
            }
        }
    }

    private var homePicker: some View {
        BridgeCard {
            Picker("Apple Home", selection: Binding(
                get: { selectedHomeId },
                set: { newHomeId in
                    selectedHomeId = newHomeId
                    path.removeAll()
                }
            )) {
                if homeKitManager.homes.isEmpty {
                    Text("No Apple homes found").tag("")
                } else {
                    ForEach(homeKitManager.homes, id: \.uniqueIdentifier) { home in
                        Text(home.name).tag(home.uniqueIdentifier.uuidString)
                    }
                }
            }
            .pickerStyle(.menu)
            .disabled(homeKitManager.homes.isEmpty)
        }
    }

    private func accessorySubtitle(_ accessory: HMAccessory) -> String {
        [accessory.room?.name ?? "Default Room", accessory.manufacturer, accessory.model]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func accessoryRow(_ accessory: HMAccessory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: accessory.isReachable ? "sensor.tag.radiowaves.forward" : "sensor.tag.radiowaves.forward.slash")
                .foregroundStyle(accessory.isReachable ? .blue : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(accessory.name)
                    .font(.headline)
                Text(accessorySubtitle(accessory))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DeviceDetailView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var wsClient: HAWebSocketClient

    let accessory: HMAccessory

    @State private var serialNumber = ""
    @State private var homeAssistantInfo: HomeAssistantDeviceInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        BridgePage(title: accessory.name, subtitle: accessory.room?.name ?? "Default Room", showsHeader: false) {
            BridgeCard {
                BridgeStatusHeader(
                    title: accessory.isReachable ? "Reachable" : "Not Reachable",
                    message: accessory.isReachable ? "Apple Home reports this device as available." : "Apple Home cannot currently reach this device.",
                    systemImage: accessory.isReachable ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    tint: accessory.isReachable ? .green : .orange
                )

                VStack(spacing: 8) {
                    BridgeInfoRow(label: "Manufacturer", value: accessory.manufacturer ?? "Unavailable")
                    BridgeInfoRow(label: "Model", value: accessory.model ?? "Unavailable")
                    BridgeInfoRow(label: "Category", value: accessory.category.localizedDescription)
                    BridgeInfoRow(label: "Serial Number", value: serialNumber.isEmpty ? "Unavailable" : serialNumber, selectable: true)
                }
            }

            homeAssistantSummary
            technicalHomeKitSection
            servicesSection
        }
        .task(id: accessory.uniqueIdentifier) {
            await loadHomeAssistantInfo()
        }
    }

    @ViewBuilder
    private var homeAssistantSummary: some View {
        if isLoading {
            BridgeCard {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking Home Assistant match")
                        .foregroundStyle(.secondary)
                }
            }
        } else if let errorMessage {
            BridgeCard {
                BridgeStatusHeader(
                    title: "Could Not Check Home Assistant",
                    message: errorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red
                )
            }
        } else if let homeAssistantInfo {
            BridgeCard {
                BridgeStatusHeader(
                    title: "Matched in Home Assistant",
                    message: homeAssistantInfo.areaName.map { "Assigned to \($0)." } ?? "Matched, but not assigned to an area.",
                    systemImage: "link.circle.fill",
                    tint: .green
                )

                VStack(spacing: 8) {
                    BridgeInfoRow(label: "Entity", value: homeAssistantInfo.entityId, selectable: true)
                    BridgeInfoRow(label: "Area", value: homeAssistantInfo.areaName ?? "Unassigned")
                }

                DisclosureGroup("Home Assistant details") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let deviceId = homeAssistantInfo.deviceId {
                            BridgeInfoRow(label: "Device ID", value: deviceId, selectable: true)
                        }
                        jsonSection(title: "State", object: homeAssistantInfo.state)
                        jsonSection(title: "Entity Registry", object: homeAssistantInfo.entity)
                        if let device = homeAssistantInfo.device {
                            jsonSection(title: "Device Registry", object: device)
                        }
                        if let area = homeAssistantInfo.area {
                            jsonSection(title: "Area Registry", object: area)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        } else {
            BridgeCard {
                BridgeStatusHeader(
                    title: "No Home Assistant Match",
                    message: "The HomeKit serial number did not match a Home Assistant entity ID.",
                    systemImage: "link.badge.plus",
                    tint: .orange
                )
            }
        }
    }

    private var technicalHomeKitSection: some View {
        BridgeCard {
            DisclosureGroup("Apple Home details") {
                VStack(spacing: 8) {
                    BridgeInfoRow(label: "Name", value: accessory.name)
                    BridgeInfoRow(label: "Identifier", value: accessory.uniqueIdentifier.uuidString, selectable: true)
                    BridgeInfoRow(label: "Room", value: accessory.room?.name ?? "Default Room")
                    BridgeInfoRow(label: "Reachable", value: accessory.isReachable ? "Yes" : "No")
                    BridgeInfoRow(label: "Blocked", value: accessory.isBlocked ? "Yes" : "No")
                    BridgeInfoRow(label: "Bridged", value: accessory.isBridged ? "Yes" : "No")
                }
                .padding(.top, 8)
            }
        }
    }

    private var servicesSection: some View {
        BridgeCard {
            DisclosureGroup("HomeKit services") {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(accessory.services, id: \.uniqueIdentifier) { service in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(service.name)
                                .font(.headline)
                            Text(service.serviceType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            ForEach(service.characteristics, id: \.uniqueIdentifier) { characteristic in
                                LabeledContent {
                                    Text(describe(characteristic.value))
                                        .font(.caption)
                                        .textSelection(.enabled)
                                        .multilineTextAlignment(.trailing)
                                } label: {
                                    Text(characteristic.characteristicType)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(12)
                        .background(.quaternary.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func jsonSection(title: String, object: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            BridgeCodeBlock(content: prettyJSON(object))
        }
    }

    private func loadHomeAssistantInfo() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        serialNumber = await homeKitManager.readSerialNumber(for: accessory)
        guard !serialNumber.isEmpty else {
            homeAssistantInfo = nil
            return
        }

        if !wsClient.isConnected {
            let connected = await wsClient.connect()
            guard connected else {
                errorMessage = wsClient.connectionError ?? "Could not connect to Home Assistant"
                homeAssistantInfo = nil
                return
            }
        }

        do {
            async let statesTask = wsClient.getStates()
            async let entitiesTask = wsClient.fetchEntityRegistry()
            async let devicesTask = wsClient.fetchDeviceRegistry()
            async let areasTask = wsClient.fetchAreas()

            let states = try await statesTask
            let entities = try await entitiesTask
            let devices = try await devicesTask
            let areas = try await areasTask

            homeAssistantInfo = matchHomeAssistantInfo(
                serialNumber: serialNumber,
                states: states,
                entities: entities,
                devices: devices,
                areas: areas
            )
        } catch {
            errorMessage = error.localizedDescription
            homeAssistantInfo = nil
        }
    }

    private func matchHomeAssistantInfo(
        serialNumber: String,
        states: [[String: Any]],
        entities: [[String: Any]],
        devices: [[String: Any]],
        areas: [[String: Any]]
    ) -> HomeAssistantDeviceInfo? {
        let state = states.first { ($0["entity_id"] as? String) == serialNumber }
        let entity = entities.first { ($0["entity_id"] as? String) == serialNumber }

        guard let state else { return nil }

        let deviceId = entity?["device_id"] as? String
        let device = deviceId.flatMap { id in
            devices.first { ($0["id"] as? String) == id }
        }
        let areaId = (entity?["area_id"] as? String) ?? (device?["area_id"] as? String)
        let area = areaId.flatMap { id in
            areas.first { ($0["area_id"] as? String) == id }
        }
        let areaName = area?["name"] as? String

        return HomeAssistantDeviceInfo(
            entityId: serialNumber,
            areaName: areaName,
            deviceId: deviceId,
            state: state,
            entity: entity ?? [:],
            device: device,
            area: area
        )
    }

    private func describe(_ value: Any?) -> String {
        guard let value else { return "Unavailable" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    private func prettyJSON(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }
}

private struct HomeAssistantDeviceInfo {
    let entityId: String
    let areaName: String?
    let deviceId: String?
    let state: [String: Any]
    let entity: [String: Any]
    let device: [String: Any]?
    let area: [String: Any]?
}
