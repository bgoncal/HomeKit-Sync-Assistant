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

    private var isNew: Bool { serverId == nil }

    var body: some View {
        ServerDetailContent(
            server: $draft,
            isNew: isNew,
            connectionState: connectionState,
            duplicateName: connections.server(matchingAddress: draft.address, excluding: draft.id)?.name,
            onTestConnection: { Task { await test() } },
            onAdd: { Task { await addAfterTesting() } },
            onAddAnyway: add,
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
            // An existing server saves as it is edited, like Settings. A new one is only
            // saved when Add is tapped, so a failed attempt never leaves a copy behind.
            // Typing another server's address is shown as "Already Added" and not saved.
            if !isNew, connections.server(matchingAddress: newValue.address, excluding: newValue.id) == nil {
                connections.update(newValue)
            }
        }
    }

    private func test() async {
        connectionState = .testing
        if isNew {
            let problem = await connections.testConnection(address: draft.normalizedAddress, token: draft.token)
            connectionState = problem.map(ConnectionTestState.failed) ?? .succeeded
        } else {
            let ok = await syncEngine.testConnection(serverId: draft.id)
            connectionState = ok ? .succeeded : .failed(
                connections.problem(forServerId: draft.id)
                    ?? ConnectionProblem(title: "Could Not Connect", message: connections.state(forServerId: draft.id).message
                        ?? "Check the address and token, then try again.")
            )
        }
    }

    private func addAfterTesting() async {
        await test()
        if connectionState == .succeeded {
            add()
        }
    }

    private func add() {
        let saved = connections.add(draft)
        Task { await connections.connect(serverId: saved.id) }
        dismiss()
    }
}

/// Everything about one Home Assistant: what it is called, and how to reach it.
struct ServerDetailContent: View {
    @Binding var server: HomeAssistantServer
    var isNew = false
    let connectionState: ConnectionTestState
    /// The server that already uses this address, if any.
    var duplicateName: String?
    var onTestConnection: () -> Void = {}
    var onAdd: () -> Void = {}
    var onAddAnyway: () -> Void = {}
    var onDelete: () -> Void = {}

    private var canAdd: Bool {
        server.isConfigured && duplicateName == nil && connectionState != .testing
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Name") {
                    TextField("Home Assistant", text: $server.name)
                        .multilineTextAlignment(.trailing)
                }
            } footer: {
                Text("Shown wherever this server is named — on Home, in previews, and in Activity.")
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

                if let duplicateName {
                    BridgeStatusRow(
                        title: "Already Added",
                        message: "“\(duplicateName)” already uses this address. Open it from the Home Assistant list to change its token instead.",
                        systemImage: "square.on.square",
                        tint: .orange
                    )
                } else if let result = connectionResult {
                    BridgeStatusRow(
                        title: result.title,
                        message: result.message,
                        systemImage: result.systemImage,
                        tint: result.tint
                    )
                }

                // Only for a server that is out of reach; a malformed address or token is
                // never worth saving.
                if isNew, case .failed = connectionState, duplicateName == nil, server.isConfigured {
                    Button("Add Anyway", action: onAddAnyway)
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
        .navigationTitle(isNew ? "Add Home Assistant" : (server.name.isEmpty ? "Home Assistant" : server.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: onAdd)
                        .disabled(!canAdd)
                }
            }
        }
    }

    private var connectionFooter: String {
        if isNew, case .failed = connectionState {
            return server.isConfigured
                ? "Nothing has been saved. Fix the address or token and tap Add again, or add it anyway if Home Assistant is simply out of reach right now."
                : "Nothing has been saved. Fix the address or token, then tap Add."
        }
        if server.address.isEmpty || server.token.isEmpty {
            return "Enter the address you use to open Home Assistant, and a long-lived access token from your profile page. The token is kept in your keychain, and iCloud Keychain carries it to your other devices."
        }
        if let problem = server.configurationProblem {
            return problem
        }
        if isNew {
            return "Add tests the connection first, so a server is only saved once it answers."
        }
        if let url = HAConfiguration.webSocketURL(for: server.address) {
            return "Connects to \(url.absoluteString)."
        }
        return "The token is kept in your keychain, and iCloud Keychain carries it to your other devices."
    }

    private var connectionResult: (title: String, message: String, systemImage: String, tint: Color)? {
        switch connectionState {
        case .idle, .testing:
            return nil
        case .succeeded:
            return ("Connected", "\(server.name) answered and accepted the token.", "checkmark.circle.fill", .green)
        case .failed(let problem):
            return (problem.title, problem.message, "exclamationmark.circle.fill", .red)
        }
    }
}
