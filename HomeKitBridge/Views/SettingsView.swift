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

    @State private var isTesting = false
    @State private var testOK: Bool?
    @State private var loginItemError: String?

    var body: some View {
        List {
            Section {
                SettingsContainer {
                    TextField("Home Assistant URL", text: $haURL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    SecureField("Access token", text: $haToken)

                    Button {
                        Task {
                            isTesting = true
                            testOK = await syncEngine.testHAConnection()
                            isTesting = false
                        }
                    } label: {
                        if isTesting {
                            ProgressView()
                        } else {
                            Label("Test Connection", systemImage: "network")
                        }
                    }
                    .disabled(isTesting)

                    if let testOK {
                        Label(testOK ? "Home Assistant is reachable" : "Connection failed", systemImage: testOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testOK ? .green : .red)
                    }
                }
                .settingsContainerRow()
            } header: {
                Text("Home Assistant")
            } footer: {
                Text("Use the same address you open in a browser, plus a long-lived access token from your Home Assistant profile.")
            }

            Section {
                SettingsContainer {
                    Toggle("Start local API automatically", isOn: $autoStartServer)

                    DisclosureGroup("Local API details") {
                        Stepper("Port: \(String(serverPort))", value: $serverPort, in: 1...65535)
                            .onChange(of: serverPort) { _, newValue in
                                server.port = newValue
                            }

                        LabeledContent("Current status", value: server.isRunning ? "Running" : "Stopped")
                    }
                }
                .settingsContainerRow()
            } header: {
                Text("Bridge")
            } footer: {
                Text("Most people can leave these defaults unchanged. Change the port only if another local service already uses it.")
            }

            Section("App") {
                SettingsContainer {
                    #if canImport(ServiceManagement) && os(macOS)
                    Toggle("Open at login", isOn: Binding(
                        get: { startAtLogin },
                        set: { newValue in
                            startAtLogin = newValue
                            setLoginItem(enabled: newValue)
                        }
                    ))

                    if let loginItemError {
                        Text(loginItemError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                    #endif

                    Button("Show Setup Again") {
                        onboardingComplete = false
                    }
                }
                .settingsContainerRow()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .padding(20)
        .navigationTitle("Settings")
    }

    #if canImport(ServiceManagement) && os(macOS)
    private func setLoginItem(enabled: Bool) {
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
    }
    #endif
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
