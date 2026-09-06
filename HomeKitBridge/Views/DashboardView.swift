import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var connections: ConnectionStore
    @EnvironmentObject private var server: HTTPServer

    var body: some View {
        DashboardContent(
            isHomeKitAuthorized: homeKitManager.isAuthorized,
            homes: homeKitManager.homes,
            connections: connections.summaries(homes: homeKitManager.homes),
            unlinkedHomes: connections.unlinkedHomes(homeKitManager.homes),
            isServerRunning: server.isRunning,
            serverPort: server.port,
            onRequestHomeKitAccess: { homeKitManager.requestAccess() },
            onConnect: { serverId in Task { await connections.connect(serverId: serverId) } },
            onDisconnect: { serverId in connections.disconnect(serverId: serverId) }
        )
    }
}

/// Both sides of the bridge, grouped per item: one section for Apple Home, one
/// for each Home Assistant server, one for the local API.
struct DashboardContent: View {
    let isHomeKitAuthorized: Bool
    let homes: [HomeSummary]
    let connections: [ConnectionSummary]
    var unlinkedHomes: [HomeSummary] = []
    let isServerRunning: Bool
    let serverPort: Int
    var onRequestHomeKitAccess: () -> Void = {}
    var onConnect: (UUID) -> Void = { _ in }
    var onDisconnect: (UUID) -> Void = { _ in }

    var body: some View {
        List {
            appleHomeSection

            if connections.isEmpty {
                noServerSection
            } else {
                ForEach(connections) { connection in
                    section(for: connection)
                }
            }

            localAPISection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Dashboard")
    }

    // MARK: Apple Home

    private var appleHomeSection: some View {
        Section {
            if homes.isEmpty {
                BridgeStatusRow(
                    title: isHomeKitAuthorized ? "No Home Loaded" : "Access Needed",
                    message: isHomeKitAuthorized
                        ? "Open the Apple Home app once on this device, then come back."
                        : "Allow access so the bridge can read your rooms and devices.",
                    systemImage: isHomeKitAuthorized ? "exclamationmark.circle.fill" : "lock.circle.fill",
                    tint: .orange
                )
                Button("Allow Access to Apple Home", action: onRequestHomeKitAccess)
            } else {
                ForEach(homes) { home in
                    homeRow(home)
                }
            }
        } header: {
            Text(SyncPlatform.appleHome.name)
        } footer: {
            if unlinkedHomes.isEmpty {
                Text("Nothing in Apple Home changes until you apply a sync.")
            } else {
                Text("\(listed(unlinkedHomes.map(\.name))) has no Home Assistant server yet. Link it in Settings before syncing.")
            }
        }
    }

    private func homeRow(_ home: HomeSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(home.name)
                Spacer(minLength: 8)
                if let serverName = serverName(forHomeId: home.id) {
                    BridgePill(
                        title: serverName,
                        systemImage: SyncPlatform.homeAssistant.symbolName,
                        tint: SyncPlatform.homeAssistant.tint
                    )
                } else {
                    BridgePill(title: "Not Linked", systemImage: "link.badge.plus", tint: .orange)
                }
            }
            Text("\(home.rooms.count) room\(home.rooms.count == 1 ? "" : "s") · \(home.accessories.count) device\(home.accessories.count == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func serverName(forHomeId homeId: String) -> String? {
        connections.first { $0.linkedHomes.contains { $0.id == homeId } }?.server.name
    }

    // MARK: Home Assistant

    private var noServerSection: some View {
        Section {
            BridgeStatusRow(
                title: "No Server Yet",
                message: "Add a Home Assistant server in Settings to start comparing both homes.",
                systemImage: "server.rack",
                tint: .orange
            )
        } header: {
            Text(SyncPlatform.homeAssistant.name)
        }
    }

    private func section(for connection: ConnectionSummary) -> some View {
        Section {
            BridgeStatusRow(
                title: connection.state.title,
                message: message(for: connection),
                systemImage: symbol(for: connection.state),
                tint: tint(for: connection.state)
            )

            LabeledContent("Address", value: connection.server.normalizedAddress.isEmpty ? "Not set" : connection.server.normalizedAddress)
                .lineLimit(1)
                .truncationMode(.middle)

            LabeledContent("Apple Homes", value: connection.linkedHomes.isEmpty ? "None" : listed(connection.linkedHomes.map(\.name)))

            if connection.state.isConnected {
                Button("Disconnect") { onDisconnect(connection.server.id) }
            } else {
                Button("Connect") { onConnect(connection.server.id) }
                    .disabled(!connection.server.isConfigured || connection.state == .connecting)
            }
        } header: {
            Text(connection.server.name)
        } footer: {
            if let problem = connection.server.configurationProblem {
                Text(problem).foregroundStyle(.orange)
            } else if let failure = connection.state.message {
                Text(failure).foregroundStyle(.red)
            } else if connection.linkedHomes.isEmpty {
                Text("This server is not paired with an Apple Home yet.")
            } else {
                Text("Areas, entity names, and device placement for \(listed(connection.linkedHomes.map(\.name))) are read from here.")
            }
        }
    }

    private func message(for connection: ConnectionSummary) -> String {
        switch connection.state {
        case .connected:
            return "Ready to compare \(connection.linkedHomes.isEmpty ? "homes" : listed(connection.linkedHomes.map(\.name)))."
        case .connecting:
            return "Opening the connection to \(connection.server.normalizedAddress)."
        case .disconnected:
            return connection.server.isConfigured
                ? "Syncing is unavailable until it connects."
                : "Finish setting this server up in Settings."
        case .failed(let message):
            return message
        }
    }

    private func symbol(for state: ServerConnectionState) -> String {
        switch state {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .disconnected: return "pause.circle.fill"
        case .failed: return "wifi.exclamationmark"
        }
    }

    private func tint(for state: ServerConnectionState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting: return .blue
        case .disconnected: return .secondary
        case .failed: return .red
        }
    }

    /// "Casa", "Casa and Beach House", "Casa, Beach House, and Studio".
    private func listed(_ names: [String]) -> String {
        names.formatted(.list(type: .and))
    }

    // MARK: Local API

    private var localAPISection: some View {
        Section {
            BridgeStatusRow(
                title: isServerRunning ? "Running" : "Stopped",
                message: isServerRunning
                    ? "Listening on this device for your own scripts."
                    : "Turn it on in Settings to control Apple Home from your own tools.",
                systemImage: isServerRunning ? "checkmark.circle.fill" : "pause.circle.fill",
                tint: isServerRunning ? .green : .secondary
            )

            LabeledContent("Port", value: String(serverPort))
        } header: {
            Text("Local API")
        } footer: {
            Text("The local API only reads and updates Apple Home. It never changes anything in Home Assistant.")
        }
    }
}
