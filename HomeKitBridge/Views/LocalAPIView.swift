import SwiftUI

/// The local HTTP API: what it is for, how to switch it on, and every endpoint.
struct LocalAPIView: View {
    @EnvironmentObject private var server: HTTPServer

    @AppStorage("serverPort") private var serverPort: Int = 8400
    @AppStorage("autoStartServer") private var autoStartServer = true

    var body: some View {
        LocalAPIContent(
            isRunning: server.isRunning,
            port: $serverPort,
            autoStart: $autoStartServer,
            onStart: { server.start() },
            onStop: { server.stop() },
            onPortChange: { server.port = $0 }
        )
    }
}

struct LocalAPIContent: View {
    let isRunning: Bool
    @Binding var port: Int
    @Binding var autoStart: Bool
    var onStart: () -> Void = {}
    var onStop: () -> Void = {}
    var onPortChange: (Int) -> Void = { _ in }

    var body: some View {
        List {
            Section {
                BridgeStatusRow(
                    title: isRunning ? "Running" : "Stopped",
                    message: isRunning
                        ? "Answering on port \(String(port)) for anything on this network."
                        : "Nothing is listening. Start it to use the endpoints below.",
                    systemImage: isRunning ? "checkmark.circle.fill" : "pause.circle.fill",
                    tint: isRunning ? .green : .secondary
                )

                if isRunning {
                    Button("Stop", action: onStop)
                } else {
                    Button("Start", action: onStart)
                }
            }

            Section {
                BridgeFeatureRow(
                    systemImage: "terminal",
                    title: "Scripts and Shortcuts",
                    message: "Read your homes, rooms and devices as JSON, then move or rename a device with a single POST — from a shell script, a Shortcut, or anything else that speaks HTTP.",
                    tint: .blue
                )
                BridgeFeatureRow(
                    systemImage: "house.and.flag",
                    title: "Other Home Automations",
                    message: "Let a Home Assistant automation, a Node-RED flow or a home server rename or move Apple Home devices without a Mac in the loop.",
                    tint: .purple
                )
                BridgeFeatureRow(
                    systemImage: "number",
                    title: "Find the Entity Behind a Device",
                    message: "Each device reports the serial number Home Assistant wrote into it, which is its entity ID — handy when a sync skipped something and you want to know why.",
                    tint: .teal
                )
            } header: {
                Text("What It Is For")
            } footer: {
                Text("The API only reads and changes Apple Home. It never touches Home Assistant, and it is unauthenticated — keep it to networks you trust.")
            }

            Section {
                Toggle("Start When the App Opens", isOn: $autoStart)
                Stepper("Port: \(String(port))", value: $port, in: 1...65535)
                    .onChange(of: port) { _, newValue in
                        onPortChange(newValue)
                    }
            } header: {
                Text("Settings")
            } footer: {
                Text("Change the port only if another app on this device already uses it.")
            }

            Section {
                ForEach(EndpointInfo.all) { endpoint in
                    NavigationLink {
                        EndpointDetailContent(endpoint: endpoint)
                    } label: {
                        row(for: endpoint)
                    }
                }
            } header: {
                Text("Endpoints")
            } footer: {
                Text("Base address: http://<this-device>:\(String(port))")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Local API")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for endpoint: EndpointInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                BridgePill(title: endpoint.method, systemImage: endpoint.symbolName, tint: endpoint.tint)
                Text(endpoint.path)
                    .font(.system(.footnote, design: .monospaced))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(endpoint.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}
