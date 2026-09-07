import SwiftUI

// MARK: - One server

struct ServerDetailView: View {
    @EnvironmentObject private var connections: ConnectionStore
    @EnvironmentObject private var syncEngine: SyncEngine
    @Environment(\.dismiss) private var dismiss

    /// `nil` while adding a server that has not been saved yet.
    let serverId: UUID?

    @State private var draft = HomeAssistantServer()
    @State private var connectionState: ConnectionTestState = .idle
    @State private var didLoad = false

    var body: some View {
        ServerDetailContent(
            server: $draft,
            isNew: serverId == nil,
            connectionState: connectionState,
            onTestConnection: testConnection,
            onDelete: {
                if let serverId {
                    connections.remove(serverId: serverId)
                }
                dismiss()
            }
        )
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let serverId, let existing = connections.server(id: serverId) {
                draft = existing
            } else {
                draft = HomeAssistantServer()
            }
        }
        .onChange(of: draft) { _, newValue in
            connectionState = .idle
            if serverId == nil {
                connections.add(newValue)
            } else {
                connections.update(newValue)
            }
        }
    }

    private func testConnection() {
        connectionState = .testing
        Task {
            let ok = await syncEngine.testConnection(serverId: draft.id)
            connectionState = ok
                ? .succeeded
                : .failed(connections.state(forServerId: draft.id).message
                          ?? "Could not connect. Check the address and token, then try again.")
        }
    }
}

/// Everything about one Home Assistant: what it is called, how to reach it, and
/// which Apple Homes it serves.
struct ServerDetailContent: View {
    @Binding var server: HomeAssistantServer
    var isNew = false
    let connectionState: ConnectionTestState
    var onTestConnection: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        Form {
            Section {
                LabeledContent("Name") {
                    TextField("Home Assistant", text: $server.name)
                        .multilineTextAlignment(.trailing)
                }
            } footer: {
                Text("Shown wherever this server is named — on the Dashboard, in previews, and in Activity.")
            }

            Section {
                LabeledContent("Address") {
                    TextField("homeassistant.local:8123", text: $server.address)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }

                LabeledContent("Token") {
                    SecureField("Long-lived access token", text: $server.token)
                        .multilineTextAlignment(.trailing)
                }

                Button(action: onTestConnection) {
                    HStack {
                        Text("Test Connection")
                        if connectionState == .testing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(connectionState == .testing || !server.isConfigured)

                if let result = connectionResult {
                    BridgeStatusRow(
                        title: result.title,
                        message: result.message,
                        systemImage: result.systemImage,
                        tint: result.tint
                    )
                }
            } header: {
                Text("Connection")
            } footer: {
                Text(connectionFooter)
            }

            if !isNew {
                Section {
                    Button("Delete Server", role: .destructive, action: onDelete)
                } footer: {
                    Text("Removing a server does not change anything in Apple Home or in Home Assistant.")
                }
            }
        }
        .navigationTitle(server.name.isEmpty ? "Home Assistant" : server.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var connectionFooter: String {
        if server.address.isEmpty || server.token.isEmpty {
            return "Enter the address you use to open Home Assistant, and a long-lived access token from your profile page. The token is stored on this device."
        }
        if let problem = server.configurationProblem {
            return problem
        }
        if let url = HAConfiguration.webSocketURL(for: server.address) {
            return "Connects to \(url.absoluteString)."
        }
        return "The token is stored on this device."
    }

    private var connectionResult: (title: String, message: String, systemImage: String, tint: Color)? {
        switch connectionState {
        case .idle, .testing:
            return nil
        case .succeeded:
            return ("Connected", "\(server.name) answered and accepted the token.", "checkmark.circle.fill", .green)
        case .failed(let message):
            return ("Not Connected", message, "exclamationmark.circle.fill", .red)
        }
    }
}
