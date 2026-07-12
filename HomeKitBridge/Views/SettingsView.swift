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
        Form {
            Section("Home Assistant") {
                TextField("URL", text: $haURL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                SecureField("Long-lived token", text: $haToken)

                HStack {
                    Button {
                        Task {
                            isTesting = true
                            testOK = await syncEngine.testHAConnection()
                            isTesting = false
                        }
                    } label: {
                        if isTesting { ProgressView() } else { Text("Test Connection") }
                    }
                    .disabled(isTesting)

                    if let testOK {
                        Label(testOK ? "Connected" : "Failed", systemImage: testOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testOK ? .green : .red)
                    }
                }
            }

            Section("Server") {
                Stepper("Port: \(String(serverPort))", value: $serverPort, in: 1...65535)
                    .onChange(of: serverPort) { _, newValue in
                        server.port = newValue
                    }

                Toggle("Start server automatically", isOn: $autoStartServer)
            }

            Section("App") {
                #if canImport(ServiceManagement) && os(macOS)
                Toggle("Start at Login", isOn: Binding(
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

                Button("Reset Onboarding") {
                    onboardingComplete = false
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
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
