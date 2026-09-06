import SwiftUI
#if canImport(ServiceManagement) && os(macOS)
import ServiceManagement
#endif

struct SettingsView: View {
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var server: HTTPServer

    @AppStorage("haURL") private var haURL = ""
    @AppStorage("haToken") private var haToken = ""
    @AppStorage("serverPort") private var serverPort: Int = 8400
    @AppStorage("autoStartServer") private var autoStartServer = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    @State private var connectionState: OnboardingConnectionState = .idle
    @State private var loginItemError: String?

    var body: some View {
        SettingsContent(
            haURL: $haURL,
            haToken: $haToken,
            connectionState: connectionState,
            serverPort: $serverPort,
            autoStartServer: $autoStartServer,
            isServerRunning: server.isRunning,
            startAtLogin: startAtLogin,
            loginItemError: loginItemError,
            onTestConnection: testConnection,
            onPortChange: { server.port = $0 },
            onStartAtLoginChange: setLoginItem(enabled:),
            onShowSetupAgain: { onboardingComplete = false }
        )
        .onChange(of: haURL) { _, _ in connectionState = .idle }
        .onChange(of: haToken) { _, _ in connectionState = .idle }
    }

    private func testConnection() {
        connectionState = .testing
        Task {
            let ok = await syncEngine.testHAConnection()
            connectionState = ok ? .succeeded : .failed("Could not connect. Check the address and token, then try again.")
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
    @Binding var haURL: String
    @Binding var haToken: String
    let connectionState: OnboardingConnectionState
    @Binding var serverPort: Int
    @Binding var autoStartServer: Bool
    let isServerRunning: Bool
    var startAtLogin: Bool = false
    var loginItemError: String?
    var onTestConnection: () -> Void = {}
    var onPortChange: (Int) -> Void = { _ in }
    var onStartAtLoginChange: (Bool) -> Void = { _ in }
    var onShowSetupAgain: () -> Void = {}

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.largeTitle.bold())
                    Text("Where the bridge connects, and what it is allowed to start on its own.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .settingsContainerRow()
            }

            Section {
                SettingsContainer {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Address")
                            .font(.headline)
                        TextField("http://homeassistant.local:8123", text: $haURL)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        note(problem: HAConfiguration.urlProblem(haURL), okMessage: connectsToMessage)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Long-lived access token")
                            .font(.headline)
                        SecureField("Paste the token", text: $haToken)
                        note(problem: HAConfiguration.tokenProblem(haToken), okMessage: nil)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            testConnectionButton
                            connectionStatus
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            testConnectionButton
                            connectionStatus
                        }
                    }
                }
                .settingsContainerRow()
            } header: {
                Text("Home Assistant")
            } footer: {
                Text("The bridge reads areas, entities, and names over this connection, and writes to Home Assistant only when a sync in that direction is applied. The token is stored on this device.")
            }

            Section {
                SettingsContainer {
                    Toggle("Start the local API when the app opens", isOn: $autoStartServer)

                    DisclosureGroup("Local API details") {
                        VStack(alignment: .leading, spacing: 10) {
                            Stepper("Port: \(String(serverPort))", value: $serverPort, in: 1...65535)
                                .onChange(of: serverPort) { _, newValue in
                                    onPortChange(newValue)
                                }

                            LabeledContent("Status", value: isServerRunning ? "Running" : "Stopped")

                            Text("The local API only reads and updates Apple Home. It never changes anything in Home Assistant.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .settingsContainerRow()
            } header: {
                Text("Local API")
            } footer: {
                Text("Leave the defaults unless another app on this device already uses port \(String(serverPort)).")
            }

            Section("App") {
                SettingsContainer {
                    #if canImport(ServiceManagement) && os(macOS)
                    Toggle("Open at login", isOn: Binding(
                        get: { startAtLogin },
                        set: { onStartAtLoginChange($0) }
                    ))

                    if let loginItemError {
                        Text(loginItemError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                    #endif

                    Button("Show the Setup Guide Again", action: onShowSetupAgain)
                }
                .settingsContainerRow()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var testConnectionButton: some View {
        Button(action: onTestConnection) {
            Label("Test Connection", systemImage: "network")
        }
        .buttonStyle(.bordered)
        .disabled(connectionState == .testing)
        .fixedSize()
    }

    private var connectsToMessage: String? {
        guard let url = HAConfiguration.webSocketURL(for: haURL) else { return nil }
        return "Will connect to \(url.absoluteString)"
    }

    @ViewBuilder
    private func note(problem: String?, okMessage: String?) -> some View {
        if let problem {
            Label(problem, systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        } else if let okMessage {
            Text(okMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        switch connectionState {
        case .idle:
            EmptyView()
        case .testing:
            Text("Connecting…")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .succeeded:
            Label("Home Assistant is reachable", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        BridgeCard {
            content
        }
    }
}

private struct SettingsContainerRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private extension View {
    func settingsContainerRow() -> some View {
        modifier(SettingsContainerRowModifier())
    }
}
