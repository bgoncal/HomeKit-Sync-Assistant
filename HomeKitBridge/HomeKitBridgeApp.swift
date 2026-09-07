import SwiftUI

@main
struct HomeKitBridgeApp: App {
    // Every service is created once in `init()`; declaring them without a default
    // value avoids building a second, throwaway HomeKit manager on every launch.
    @StateObject private var homeKitManager: HomeKitManager
    @StateObject private var logStore: LogStore
    @StateObject private var connections: ConnectionStore

    @StateObject private var syncEngine: SyncEngine
    @StateObject private var httpServer: HTTPServer
    @StateObject private var scheduledActionManager: ScheduledActionManager

    @State private var didStartLaunchServices = false

    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("autoStartServer") private var autoStartServer = true

    init() {
        let homeKit = HomeKitManager()
        let logs = LogStore()
        let connections = ConnectionStore(
            cloud: UbiquitousConfigurationSyncStore(),
            tokens: KeychainTokenStore()
        )
        _homeKitManager = StateObject(wrappedValue: homeKit)
        _logStore = StateObject(wrappedValue: logs)
        _connections = StateObject(wrappedValue: connections)

        let sync = SyncEngine(homeKitManager: homeKit, logStore: logs, connections: connections)
        _syncEngine = StateObject(wrappedValue: sync)
        _httpServer = StateObject(wrappedValue: HTTPServer(homeKit: homeKit, logStore: logs))
        _scheduledActionManager = StateObject(
            wrappedValue: ScheduledActionManager(
                syncEngine: sync,
                logStore: logs,
                homeKitManager: homeKit,
                connections: connections
            )
        )
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
            .environmentObject(connections)
            .environmentObject(syncEngine)
            .environmentObject(httpServer)
            .environmentObject(scheduledActionManager)
            .onAppear {
                guard !didStartLaunchServices, !ProcessInfo.processInfo.isRunningTests else { return }
                didStartLaunchServices = true

                if autoStartServer {
                    httpServer.start()
                }

                scheduledActionManager.refreshSchedule()

                Task {
                    await connections.connectAll()
                }
            }
        }
    }
}

extension ProcessInfo {
    /// True while the app is only hosting the test bundle. Launch work (HomeKit
    /// access, the local server, the Home Assistant connection) is skipped then, so
    /// tests never prompt for permission or touch the network.
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil
    }
}
