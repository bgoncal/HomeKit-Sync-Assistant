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

/// Status of both sides of the bridge, rendered from plain values.
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
        BridgePage(
            title: "Dashboard",
            subtitle: "Both sides have to be connected before the bridge can compare or change anything."
        ) {
            VStack(spacing: 14) {
                appleHomeCard
                homeAssistantCard
                localAPICard
            }
        }
    }

    private var appleHomeCard: some View {
        BridgeCard {
            BridgeStatusHeader(
                title: SyncPlatform.appleHome.name,
                message: appleHomeMessage,
                systemImage: isHomeKitAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                tint: isHomeKitAuthorized ? .green : .orange
            )

            if let home {
                HStack(spacing: 12) {
                    summaryMetric("Rooms", value: home.rooms.count, icon: "door.left.hand.open")
                    summaryMetric("Devices", value: home.accessories.count, icon: "sensor.tag.radiowaves.forward")
                }

                DisclosureGroup("Apple Home details") {
                    VStack(spacing: 8) {
                        BridgeInfoRow(label: "Home being synced", value: home.name)
                        BridgeInfoRow(label: "Identifier", value: home.id, selectable: true)
                    }
                    .padding(.top, 8)
                }
            } else {
                Button(action: onRequestHomeKitAccess) {
                    Label("Allow Access to Apple Home", systemImage: "lock.open")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var appleHomeMessage: String {
        guard isHomeKitAuthorized else {
            return "Waiting for permission to read your rooms and devices."
        }
        guard let home else {
            return "Access granted, but no home has loaded yet. Open the Apple Home app once, then come back."
        }
        return "Reading “\(home.name)”. Nothing here changes until you apply a sync."
    }

    private var homeAssistantCard: some View {
        BridgeCard {
            BridgeStatusHeader(
                title: SyncPlatform.homeAssistant.name,
                message: homeAssistantMessage,
                systemImage: isHomeAssistantConnected ? "checkmark.circle.fill" : "wifi.exclamationmark",
                tint: isHomeAssistantConnected ? .green : .red
            )

            HStack {
                if isHomeAssistantConnected {
                    Button(action: onDisconnectHomeAssistant) {
                        Label("Disconnect", systemImage: "power")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: onConnectHomeAssistant) {
                        Label("Connect", systemImage: "bolt.horizontal")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }

            if let homeAssistantError, !homeAssistantError.isEmpty {
                DisclosureGroup("Why the connection failed") {
                    Text(homeAssistantError)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
            }
        }
    }

    private var homeAssistantMessage: String {
        if isHomeAssistantConnected {
            return homeAssistantAddress.isEmpty
                ? "Connected. Areas, entities, and names can be compared."
                : "Connected to \(homeAssistantAddress). Areas, entities, and names can be compared."
        }
        return homeAssistantAddress.isEmpty
            ? "No address set yet. Add one in Settings before syncing."
            : "Not connected to \(homeAssistantAddress). Syncing is unavailable until it connects."
    }

    private var localAPICard: some View {
        BridgeCard {
            BridgeStatusHeader(
                title: "Local API",
                message: isServerRunning
                    ? "Listening on port \(serverPort) for your own scripts and automations on this network."
                    : "Stopped. Turn it on in Settings if you want to control Apple Home from your own tools.",
                systemImage: isServerRunning ? "checkmark.circle.fill" : "pause.circle.fill",
                tint: isServerRunning ? .green : .orange
            )

            DisclosureGroup("Local API details") {
                VStack(spacing: 8) {
                    BridgeInfoRow(label: "Status", value: isServerRunning ? "Running" : "Stopped")
                    BridgeInfoRow(label: "Port", value: String(serverPort), selectable: true)
                }
                .padding(.top, 8)
            }
        }
    }

    private func summaryMetric(_ title: String, value: Int, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.title2.bold())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
