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

    @State private var connectionState: ConnectionTestState = .idle
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
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .localAPI:
                EndpointsView()
            }
        }
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

/// Where Settings can push to.
enum SettingsRoute: Hashable {
    case localAPI
}

struct SettingsContent: View {
    @Binding var haURL: String
    @Binding var haToken: String
    let connectionState: ConnectionTestState
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
        Form {
            homeAssistantSection
            localAPISection
            appSection
        }
        .navigationTitle("Settings")
    }

    // MARK: Home Assistant

    private var homeAssistantSection: some View {
        Section {
            LabeledContent("Address") {
                TextField("homeassistant.local:8123", text: $haURL)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
            }

            LabeledContent("Token") {
                SecureField("Long-lived access token", text: $haToken)
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
            .disabled(connectionState == .testing)

            if let result = connectionResult {
                BridgeStatusRow(
                    title: result.title,
                    message: result.message,
                    systemImage: result.systemImage,
                    tint: result.tint
                )
            }
        } header: {
            Text(SyncPlatform.homeAssistant.name)
        } footer: {
            Text(homeAssistantFooter)
        }
    }

    private var homeAssistantFooter: String {
        if !haURL.isEmpty, let problem = HAConfiguration.urlProblem(haURL) {
            return problem
        }
        if !haToken.isEmpty, let problem = HAConfiguration.tokenProblem(haToken) {
            return problem
        }
        if haURL.isEmpty || haToken.isEmpty {
            return "Enter the address you use to open Home Assistant, and a long-lived access token from your profile page."
        }
        if let url = HAConfiguration.webSocketURL(for: haURL) {
            return "Connects to \(url.absoluteString). The token is stored on this device and is only sent to Home Assistant."
        }
        return "The token is stored on this device and is only sent to Home Assistant."
    }

    private var connectionResult: (title: String, message: String, systemImage: String, tint: Color)? {
        switch connectionState {
        case .idle, .testing:
            return nil
        case .succeeded:
            return ("Connected", "Home Assistant answered and accepted the token.", "checkmark.circle.fill", .green)
        case .failed(let message):
            return ("Not Connected", message, "exclamationmark.circle.fill", .red)
        }
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
            Text("Scheduled actions only run while the app is open.")
        }
    }
}
