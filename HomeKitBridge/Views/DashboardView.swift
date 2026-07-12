import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var wsClient: HAWebSocketClient
    @EnvironmentObject private var server: HTTPServer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Dashboard")
                    .font(.largeTitle.bold())

                statusCard(
                    title: "HomeKit",
                    icon: "house.fill",
                    color: homeKitManager.isAuthorized ? .green : .orange,
                    lines: [
                        homeKitManager.isAuthorized ? "Connected" : "Not authorized",
                        "Home: \(homeKitManager.primaryHome?.name ?? "—")",
                        "Accessories: \(homeKitManager.primaryHome?.accessories.count ?? 0)"
                    ]
                )

                VStack(alignment: .leading, spacing: 8) {
                    statusCard(
                        title: "Home Assistant WebSocket",
                        icon: "bolt.horizontal.fill",
                        color: wsClient.isConnected ? .green : .red,
                        lines: [
                            wsClient.isConnected ? "Connected" : "Disconnected",
                            wsClient.connectionError ?? "No connection errors"
                        ]
                    )

                    HStack {
                        if wsClient.isConnected {
                            Button("Disconnect") { wsClient.disconnect() }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Connect") {
                                Task { _ = await wsClient.connect() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    }
                }

                statusCard(
                    title: "HTTP API Server",
                    icon: "server.rack",
                    color: server.isRunning ? .green : .orange,
                    lines: [
                        server.isRunning ? "Running" : "Stopped",
                        "Port: \(String(server.port))"
                    ]
                )
            }
            .padding(20)
        }
    }

    private func statusCard(title: String, icon: String, color: Color, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
