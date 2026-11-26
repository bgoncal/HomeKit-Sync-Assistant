import AppIntents
import SwiftUI

@main
struct HomeKitBridgeApp: App {
    // Every service is created once in `init()`; declaring them without a default
    // value avoids building a second, throwaway HomeKit manager on every launch.
    @StateObject private var homeKitManager: HomeKitManager
    @StateObject private var logStore: LogStore
    @StateObject private var connections: ConnectionStore
    @StateObject private var preferences: SyncPreferencesStore

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
        let preferences = SyncPreferencesStore(cloud: UbiquitousConfigurationSyncStore())
        _preferences = StateObject(wrappedValue: preferences)

        // Copies of one server left by earlier versions were folded at load; carry their
        // hand-made pairings over and say so in Activity, rather than tidy up silently.
        let folded = connections.takeFoldedServers()
        if !folded.isEmpty {
            preferences.moveManualPairings(from: folded)
            let names = Set(folded.values.compactMap { connections.server(id: $0)?.name }).sorted()
            logs.add(
                category: .server,
                message: "Removed \(folded.count) duplicate server\(folded.count == 1 ? "" : "s")",
                details: "Copies of \(names.map { "“\($0)”" }.joined(separator: ", ")) that pointed at the same Home Assistant with the same token. Pairings now use the one that was kept."
            )
        }

        let sync = SyncEngine(homeKitManager: homeKit, logStore: logs, connections: connections, preferences: preferences)
        _syncEngine = StateObject(wrappedValue: sync)

        // What the Shortcuts actions use, so they act on the same services as the screens.
        AppDependencyManager.shared.add(dependency: sync)
        AppDependencyManager.shared.add(dependency: homeKit)
        AppDependencyManager.shared.add(dependency: connections)
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
            .environmentObject(preferences)
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
