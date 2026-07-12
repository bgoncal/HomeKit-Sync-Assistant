import SwiftUI

@main
struct HomeKitBridgeApp: App {
    @StateObject private var homeKitManager = HomeKitManager()
    @StateObject private var logStore = LogStore()
    @StateObject private var wsClient = HAWebSocketClient()

    @StateObject private var syncEngine: SyncEngine
    @StateObject private var httpServer: HTTPServer

    @State private var didStartLaunchServices = false

    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("autoStartServer") private var autoStartServer = true

    init() {
        UserDefaults.standard.register(defaults: [
            "haURL": HAConfiguration.defaultURL,
            "haToken": HAConfiguration.defaultToken
        ])

        let homeKit = HomeKitManager()
        let logs = LogStore()
        let ws = HAWebSocketClient()
        _homeKitManager = StateObject(wrappedValue: homeKit)
        _logStore = StateObject(wrappedValue: logs)
        _wsClient = StateObject(wrappedValue: ws)
        _syncEngine = StateObject(wrappedValue: SyncEngine(homeKitManager: homeKit, logStore: logs, wsClient: ws))
        _httpServer = StateObject(wrappedValue: HTTPServer(homeKit: homeKit, logStore: logs))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(homeKitManager)
            .environmentObject(logStore)
            .environmentObject(wsClient)
            .environmentObject(syncEngine)
            .environmentObject(httpServer)
            .onAppear {
                guard !didStartLaunchServices else { return }
                didStartLaunchServices = true

                if autoStartServer {
                    httpServer.start()
                }

                Task {
                    _ = await wsClient.connect()
                }
            }
        }
    }
}
