import SwiftUI
#if canImport(ServiceManagement) && os(macOS)
import ServiceManagement
#endif

/// Where Settings can push to.
enum SettingsRoute: Hashable {
    case server(UUID)
    case newServer
    case localAPI
    case scheduledActions
}

struct SettingsView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
    @EnvironmentObject private var connections: ConnectionStore
    @EnvironmentObject private var scheduledActionManager: ScheduledActionManager
    @EnvironmentObject private var server: HTTPServer

    @AppStorage("serverPort") private var serverPort: Int = 8400
    @AppStorage("autoStartServer") private var autoStartServer = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    @State private var loginItemError: String?

    var body: some View {
        SettingsContent(
            connections: connections.summaries(homes: homeKitManager.homes),
            homes: homeKitManager.homes,
            serverPort: $serverPort,
            autoStartServer: $autoStartServer,
            isServerRunning: server.isRunning,
            scheduleCount: scheduledActionManager.schedules.count,
            startAtLogin: startAtLogin,
            loginItemError: loginItemError,
            onLink: { homeId, serverId in connections.link(homeId: homeId, toServerId: serverId) },
            onPortChange: { server.port = $0 },
            onStartAtLoginChange: setLoginItem(enabled:),
            onShowSetupAgain: { onboardingComplete = false }
        )
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .server(let id):
                ServerDetailView(serverId: id)
            case .newServer:
                ServerDetailView(serverId: nil)
            case .localAPI:
                EndpointsView()
            case .scheduledActions:
                ActionsView()
            }
        }
    }

    private func setLoginItem(enabled: Bool) {
        startAtLogin = enabled
        #if canImport(ServiceManagement) && os(macOS)
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        #endif
    }
}

struct SettingsContent: View {
    let connections: [ConnectionSummary]
    let homes: [HomeSummary]
    @Binding var serverPort: Int
    @Binding var autoStartServer: Bool
    let isServerRunning: Bool
    var scheduleCount: Int = 0
    var startAtLogin: Bool = false
    var loginItemError: String?
    /// Scheduled syncs only exist on the Mac; the section is absent elsewhere.
    var supportsScheduledActions: Bool = ScheduledActionManager.isSupported
    var onLink: (String, UUID?) -> Void = { _, _ in }
    var onPortChange: (Int) -> Void = { _ in }
    var onStartAtLoginChange: (Bool) -> Void = { _ in }
    var onShowSetupAgain: () -> Void = {}

    var body: some View {
        Form {
            serversSection
            homesSection
            localAPISection
            appSection
        }
        .navigationTitle("Settings")
    }

    // MARK: Servers

    private var serversSection: some View {
        Section {
            ForEach(connections) { connection in
                NavigationLink(value: SettingsRoute.server(connection.server.id)) {
                    serverRow(connection)
                }
            }

            NavigationLink(value: SettingsRoute.newServer) {
                Label("Add Home Assistant", systemImage: "plus")
            }
        } header: {
            Text(SyncPlatform.homeAssistant.name)
        } footer: {
            Text(connections.isEmpty
                 ? "Add the Home Assistant you want to keep in sync. You can add more than one."
                 : "Each server keeps its own address and token. Open one to change them or to choose which Apple Homes it serves.")
        }
    }

    private func serverRow(_ connection: ConnectionSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(connection.server.name)
                Spacer(minLength: 8)
                BridgePill(
                    title: connection.state.title,
                    systemImage: pillSymbol(for: connection.state),
                    tint: pillTint(for: connection.state)
                )
            }
            Text(connection.server.normalizedAddress.isEmpty ? "No address yet" : connection.server.normalizedAddress)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }

    private func pillSymbol(for state: ServerConnectionState) -> String {
        switch state {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .disconnected: return "circle.dashed"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    private func pillTint(for state: ServerConnectionState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting: return .blue
        case .disconnected: return .secondary
        case .failed: return .red
        }
    }

    // MARK: Apple homes

    @ViewBuilder
    private var homesSection: some View {
        if !homes.isEmpty {
            Section {
                ForEach(homes) { home in
                    Picker(home.name, selection: Binding(
                        get: { serverId(forHomeId: home.id) },
                        set: { onLink(home.id, $0) }
                    )) {
                        Text("Not Linked").tag(UUID?.none)
                        ForEach(connections) { connection in
                            Text(connection.server.name).tag(UUID?.some(connection.server.id))
                        }
                    }
                }
            } header: {
                Text("Apple Homes")
            } footer: {
                Text("Each home is paired with one server, because its devices carry entity IDs from that one instance.")
            }
        }
    }

    private func serverId(forHomeId homeId: String) -> UUID? {
        connections.first { $0.linkedHomes.contains { $0.id == homeId } }?.server.id
    }

    // MARK: Local API

    private var localAPISection: some View {
        Section {
            Toggle("Start When the App Opens", isOn: $autoStartServer)

            Stepper("Port: \(String(serverPort))", value: $serverPort, in: 1...65535)
                .onChange(of: serverPort) { _, newValue in
                    onPortChange(newValue)
                }

            LabeledContent("Status", value: isServerRunning ? "Running" : "Stopped")

            NavigationLink(value: SettingsRoute.localAPI) {
                Text("Endpoint Reference")
            }
        } header: {
            Text("Local API")
        } footer: {
            Text("Lets your own scripts read and change Apple Home over this network. It never changes anything in Home Assistant. Change the port only if another app already uses it.")
        }
    }

    // MARK: App

    private var appSection: some View {
        Section {
            if supportsScheduledActions {
                NavigationLink(value: SettingsRoute.scheduledActions) {
                    LabeledContent("Scheduled Syncs", value: scheduleCount == 0 ? "None" : scheduleCount.formatted())
                }
            }

            #if canImport(ServiceManagement) && os(macOS)
            Toggle("Open at Login", isOn: Binding(
                get: { startAtLogin },
                set: { onStartAtLoginChange($0) }
            ))

            if let loginItemError {
                Text(loginItemError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            #endif

            Button("Show Setup Guide Again", action: onShowSetupAgain)
        } header: {
            Text("App")
        } footer: {
            Text(supportsScheduledActions
                 ? "Scheduled syncs run while this Mac is awake and the app is open."
                 : "Syncs run when you ask for them. Scheduled syncs are a Mac feature, because iPhone and iPad suspend the app once you leave it.")
        }
    }
}

// MARK: - One server

private struct ServerDetailView: View {
    @EnvironmentObject private var homeKitManager: HomeKitManager
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
            homes: homeKitManager.homes,
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
                // A first server serves every home found so far; that is what people mean.
                draft = HomeAssistantServer(linkedHomeIds: connections.servers.isEmpty ? homeKitManager.homes.map(\.id) : [])
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
    let homes: [HomeSummary]
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

            Section {
                if homes.isEmpty {
                    Text("No Apple Home has loaded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(homes) { home in
                        Toggle(home.name, isOn: Binding(
                            get: { server.linkedHomeIds.contains(home.id) },
                            set: { isOn in
                                if isOn {
                                    if !server.linkedHomeIds.contains(home.id) {
                                        server.linkedHomeIds.append(home.id)
                                    }
                                } else {
                                    server.linkedHomeIds.removeAll { $0 == home.id }
                                }
                            }
                        ))
                    }
                }
            } header: {
                Text("Apple Homes Served")
            } footer: {
                Text("Turning a home on here takes it off any other server.")
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
