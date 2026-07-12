import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var wsClient: HAWebSocketClient
    @EnvironmentObject private var server: HTTPServer

    var body: some View {
        BridgePage(
            title: "HomeKit Bridge",
            subtitle: "A quick view of whether Apple Home, Home Assistant, and the local bridge are ready."
        ) {
            VStack(spacing: 14) {
                homeStatusCard
                homeAssistantStatusCard
                serverStatusCard
            }
        }
    }

    private var homeStatusCard: some View {
        BridgeCard {
            BridgeStatusHeader(
                title: "Apple Home",
                message: homeKitManager.isAuthorized ? "Ready to read and update your selected home." : "Waiting for HomeKit access.",
                systemImage: homeKitManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                tint: homeKitManager.isAuthorized ? .green : .orange
            )

            if let home = homeKitManager.primaryHome {
                HStack(spacing: 12) {
                    summaryMetric("Rooms", value: home.rooms.count, icon: "door.left.hand.open")
                    summaryMetric("Devices", value: home.accessories.count, icon: "sensor.tag.radiowaves.forward")
                }

                DisclosureGroup("Home details") {
                    VStack(spacing: 8) {
                        BridgeInfoRow(label: "Selected Home", value: home.name)
                        BridgeInfoRow(label: "Identifier", value: home.uniqueIdentifier.uuidString, selectable: true)
                    }
                    .padding(.top, 8)
                }
            } else {
                Text("Open Apple Home once, then return here to allow the bridge to discover your homes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var homeAssistantStatusCard: some View {
        BridgeCard {
            BridgeStatusHeader(
                title: "Home Assistant",
                message: wsClient.isConnected ? "Connected and ready to compare devices." : "Disconnected. Connect before syncing.",
                systemImage: wsClient.isConnected ? "checkmark.circle.fill" : "wifi.exclamationmark",
                tint: wsClient.isConnected ? .green : .red
            )

            HStack {
                if wsClient.isConnected {
                    Button {
                        wsClient.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "power")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        Task { _ = await wsClient.connect() }
                    } label: {
                        Label("Connect", systemImage: "bolt.horizontal")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }

            if let connectionError = wsClient.connectionError, !connectionError.isEmpty {
                DisclosureGroup("Connection details") {
                    Text(connectionError)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 8)
                }
            }
        }
    }

    private var serverStatusCard: some View {
        BridgeCard {
            BridgeStatusHeader(
                title: "Local API",
                message: server.isRunning ? "Running for local automations and integrations." : "Stopped. Enable it in Settings when needed.",
                systemImage: server.isRunning ? "checkmark.circle.fill" : "pause.circle.fill",
                tint: server.isRunning ? .green : .orange
            )

            DisclosureGroup("Technical details") {
                VStack(spacing: 8) {
                    BridgeInfoRow(label: "Status", value: server.isRunning ? "Running" : "Stopped")
                    BridgeInfoRow(label: "Port", value: String(server.port), selectable: true)
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
