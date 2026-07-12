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
                Text("Devices")
                    .font(.largeTitle.bold())

                homePicker

                if let selectedHome {
                    List(selectedHome.accessories, id: \.uniqueIdentifier) { accessory in
                        NavigationLink(value: accessory.uniqueIdentifier.uuidString) {
                            accessoryRow(accessory)
                        }
                    }
                } else {
                    Spacer()
                    ContentUnavailableView("No Apple Home Selected", systemImage: "house", description: Text("Choose an Apple Home to list its devices."))
                    Spacer()
                }
            }
            .padding(20)
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
        HStack(spacing: 8) {
            Text("Apple Home")
                .font(.headline)

            Picker("Apple Home", selection: Binding(
                get: { selectedHomeId },
                set: { newHomeId in
                    selectedHomeId = newHomeId
                    path.removeAll()
                }
            )) {
                if homeKitManager.homes.isEmpty {
                    Text("No HomeKit homes found").tag("")
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
        [accessory.manufacturer, accessory.model]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func accessoryRow(_ accessory: HMAccessory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sensor.tag.radiowaves.forward")
                .foregroundStyle(.blue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(accessory.name)
                    .font(.headline)
                Text(accessory.room?.name ?? "Default Room")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(accessorySubtitle(accessory))
                    .font(.caption)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(accessory.name)
                    .font(.largeTitle.bold())

                infoSection(title: "Apple Home", rows: homeKitRows)

                servicesSection

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading Home Assistant data")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                if let homeAssistantInfo {
                    homeAssistantSection(homeAssistantInfo)
                } else if !isLoading {
                    ContentUnavailableView("No Home Assistant Match", systemImage: "link.badge.plus", description: Text("The HomeKit serial number did not match a Home Assistant entity ID."))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .task(id: accessory.uniqueIdentifier) {
            await loadHomeAssistantInfo()
        }
    }

    private var homeKitRows: [InfoRow] {
        [
            InfoRow(label: "Name", value: accessory.name),
            InfoRow(label: "Identifier", value: accessory.uniqueIdentifier.uuidString),
            InfoRow(label: "Room", value: accessory.room?.name ?? "Default Room"),
            InfoRow(label: "Manufacturer", value: accessory.manufacturer ?? "Unavailable"),
            InfoRow(label: "Model", value: accessory.model ?? "Unavailable"),
            InfoRow(label: "Serial Number", value: serialNumber.isEmpty ? "Unavailable" : serialNumber),
            InfoRow(label: "Reachable", value: accessory.isReachable ? "Yes" : "No"),
            InfoRow(label: "Blocked", value: accessory.isBlocked ? "Yes" : "No"),
            InfoRow(label: "Bridged", value: accessory.isBridged ? "Yes" : "No"),
            InfoRow(label: "Category", value: accessory.category.localizedDescription)
        ]
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HomeKit Services")
                .font(.title2.bold())

            ForEach(accessory.services, id: \.uniqueIdentifier) { service in
                VStack(alignment: .leading, spacing: 8) {
                    Text(service.name)
                        .font(.headline)
                    Text(service.serviceType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    ForEach(service.characteristics, id: \.uniqueIdentifier) { characteristic in
                        HStack(alignment: .top) {
                            Text(characteristic.characteristicType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Spacer()
                            Text(describe(characteristic.value))
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func homeAssistantSection(_ info: HomeAssistantDeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Home Assistant")
                .font(.title2.bold())

            infoSection(title: "Match", rows: [
                InfoRow(label: "Matched Entity ID", value: info.entityId),
                InfoRow(label: "Area", value: info.areaName ?? "Unassigned"),
                InfoRow(label: "Device ID", value: info.deviceId ?? "Unavailable")
            ])

            jsonSection(title: "State", object: info.state)
            jsonSection(title: "Entity Registry", object: info.entity)

            if let device = info.device {
                jsonSection(title: "Device Registry", object: device)
            }

            if let area = info.area {
                jsonSection(title: "Area Registry", object: area)
            }
        }
    }

    private func infoSection(title: String, rows: [InfoRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row in
                    HStack(alignment: .top) {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                            .frame(width: 130, alignment: .leading)
                        Text(row.value)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding()
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func jsonSection(title: String, object: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(prettyJSON(object))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.black.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 6))
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

private struct InfoRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
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
