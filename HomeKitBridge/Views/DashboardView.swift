import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var wsClient: HAWebSocketClient
    @EnvironmentObject private var server: HTTPServer

    @AppStorage("haURL") private var haURL = ""

    var body: some View {
        DashboardContent(
            isHomeKitAuthorized: homeKitManager.isAuthorized,
            home: homeKitManager.selectedHome,
            isHomeAssistantConnected: wsClient.isConnected,
            homeAssistantError: wsClient.connectionError,
            homeAssistantAddress: HAConfiguration.normalizedURL(haURL),
            isServerRunning: server.isRunning,
            serverPort: server.port,
            onRequestHomeKitAccess: { homeKitManager.requestAccess() },
            onConnectHomeAssistant: { Task { _ = await wsClient.connect() } },
            onDisconnectHomeAssistant: { wsClient.disconnect() }
        )
    }
}

/// Status of both sides of the bridge, one grouped section each.
struct DashboardContent: View {
    let isHomeKitAuthorized: Bool
    let home: HomeSummary?
    let isHomeAssistantConnected: Bool
    let homeAssistantError: String?
    let homeAssistantAddress: String
    let isServerRunning: Bool
    let serverPort: Int
    var onRequestHomeKitAccess: () -> Void = {}
    var onConnectHomeAssistant: () -> Void = {}
    var onDisconnectHomeAssistant: () -> Void = {}

    var body: some View {
        List {
            appleHomeSection
            homeAssistantSection
            localAPISection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Dashboard")
    }

    // MARK: Apple Home

    private var appleHomeSection: some View {
        Section {
            BridgeStatusRow(
                title: appleHomeStatusTitle,
                message: appleHomeStatusMessage,
                systemImage: isHomeKitAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                tint: isHomeKitAuthorized ? .green : .orange
            )

            if let home {
                LabeledContent("Home", value: home.name)
                LabeledContent("Rooms", value: home.rooms.count.formatted())
                LabeledContent("Devices", value: home.accessories.count.formatted())
            } else {
                Button("Allow Access to Apple Home", action: onRequestHomeKitAccess)
            }
        } header: {
            Text(SyncPlatform.appleHome.name)
        } footer: {
            Text("The bridge reads your rooms and devices. Nothing here changes until you apply a sync.")
        }
    }

    private var appleHomeStatusTitle: String {
        guard isHomeKitAuthorized else { return "Waiting for access" }
        return home == nil ? "No home loaded" : "Connected"
    }

    private var appleHomeStatusMessage: String {
        guard isHomeKitAuthorized else {
            return "Allow access so the bridge can read your rooms and devices."
        }
        guard let home else {
            return "Open the Apple Home app once on this device, then come back."
        }
        return "Syncing “\(home.name)”."
    }

    // MARK: Home Assistant

    private var homeAssistantSection: some View {
        Section {
            BridgeStatusRow(
                title: isHomeAssistantConnected ? "Connected" : "Not connected",
                message: homeAssistantStatusMessage,
                systemImage: isHomeAssistantConnected ? "checkmark.circle.fill" : "wifi.exclamationmark",
                tint: isHomeAssistantConnected ? .green : .red
            )

            if !homeAssistantAddress.isEmpty {
                LabeledContent("Address", value: homeAssistantAddress)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if isHomeAssistantConnected {
                Button("Disconnect", action: onDisconnectHomeAssistant)
            } else {
                Button("Connect", action: onConnectHomeAssistant)
            }
        } header: {
            Text(SyncPlatform.homeAssistant.name)
        } footer: {
            if let homeAssistantError, !homeAssistantError.isEmpty, !isHomeAssistantConnected {
                Text(homeAssistantError)
                    .foregroundStyle(.red)
            } else {
                Text("Areas, entity names, and device placement are read over this connection.")
            }
        }
    }

    private var homeAssistantStatusMessage: String {
        if isHomeAssistantConnected {
            return "Ready to compare both homes."
        }
        return homeAssistantAddress.isEmpty
            ? "Add the address and token in Settings."
            : "Syncing is unavailable until it connects."
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
