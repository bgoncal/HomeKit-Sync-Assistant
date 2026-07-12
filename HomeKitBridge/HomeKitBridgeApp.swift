import SwiftUI

@main
struct HomeKitBridgeApp: App {
    @StateObject private var homeKitManager = HomeKitManager()
    @StateObject private var logStore = LogStore()
    @StateObject private var wsClient = HAWebSocketClient()

    @StateObject private var syncEngine: SyncEngine
    @StateObject private var httpServer: HTTPServer

    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("autoStartServer") private var autoStartServer = true

    init() {
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
                if autoStartServer {
                    httpServer.start()
                }
            }
        }
    }
}
