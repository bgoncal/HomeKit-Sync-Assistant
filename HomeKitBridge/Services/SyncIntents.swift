import AppIntents
import Foundation

// Shortcuts actions. They only ever run because the person ran them — a shortcut,
// an automation they built, or a tap — never on a timer of the app's own, which is
// why they are allowed on iPhone and iPad where scheduled syncs are not.

extension SyncOperation: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Sync"

    static let caseDisplayRepresentations: [SyncOperation: DisplayRepresentation] = [
            .roomsHAToHome: "Rooms, from Home Assistant to Apple Home",
            .roomsHomeToHA: "Rooms, from Apple Home to Home Assistant",
            .devicePlacementHAToHome: "Device placement, from Home Assistant to Apple Home",
            .devicePlacementHomeToHA: "Device placement, from Apple Home to Home Assistant",
            .deviceNamesHAToHome: "Device names, from Home Assistant to Apple Home",
            .deviceNamesHomeToHA: "Device names, from Apple Home to Home Assistant",
            .zonesHAToHome: "Floors and zones, from Home Assistant to Apple Home",
            .zonesHomeToHA: "Floors and zones, from Apple Home to Home Assistant",
            .scenesHAToHome: "Scenes, from Home Assistant to Apple Home",
            .scenesHomeToHA: "Scenes, from Apple Home to Home Assistant"
    ]
}

/// The pair a shortcut syncs: the home Apple Home has selected, and the server last
/// used with it — the same pair the Sync screen offers first.
@MainActor
private func intentPair(homeKit: HomeKitManager, connections: ConnectionStore) async throws -> (homeId: String, serverId: UUID) {
    // HomeKit fills its homes in shortly after launch.
    for _ in 0..<20 where homeKit.homes.isEmpty {
        try await Task.sleep(for: .milliseconds(250))
    }
    guard let home = homeKit.selectedHome ?? homeKit.homes.first else {
        throw BridgeError.notFound("No Apple Home is available. Open Home Sync Assistant and allow access to Apple Home.")
    }
    guard let server = connections.suggestedServer(forHomeId: home.id) ?? connections.servers.first else {
        throw BridgeError.notFound("No Home Assistant is set up. Add one in Home Sync Assistant first.")
    }
    return (home.id, server.id)
}

struct PreviewSyncIntent: AppIntent {
    static let title: LocalizedStringResource = "Preview Sync"
    static let description = IntentDescription("Lists what a sync would change, without changing anything.")
    // Apple Home is only reachable while the app is in front.
    static let openAppWhenRun = true

    @Parameter(title: "Sync", default: .devicePlacementHAToHome)
    var operation: SyncOperation

    @Dependency private var syncEngine: SyncEngine
    @Dependency private var homeKit: HomeKitManager
    @Dependency private var connections: ConnectionStore

    static var parameterSummary: some ParameterSummary {
        Summary("Preview \(\.$operation)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let pair = try await intentPair(homeKit: homeKit, connections: connections)
        let plan = try await syncEngine.dryRun(operation, homeId: pair.homeId, serverId: pair.serverId)
        return .result(value: plan.changes.count, dialog: "\(plan.summary)")
    }
}

struct SyncNowIntent: AppIntent {
    static let title: LocalizedStringResource = "Sync Now"
    static let description = IntentDescription("Previews a sync and applies every change it lists. The last sync can be undone in the app.")
    static let openAppWhenRun = true

    @Parameter(title: "Sync", default: .devicePlacementHAToHome)
    var operation: SyncOperation

    @Dependency private var syncEngine: SyncEngine
    @Dependency private var homeKit: HomeKitManager
    @Dependency private var connections: ConnectionStore

    static var parameterSummary: some ParameterSummary {
        Summary("Sync \(\.$operation)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let pair = try await intentPair(homeKit: homeKit, connections: connections)
        let plan = try await syncEngine.dryRun(operation, homeId: pair.homeId, serverId: pair.serverId)
        guard !plan.changes.isEmpty else {
            return .result(value: 0, dialog: "\(plan.summary)")
        }
        try await syncEngine.execute(plan)
        let count = plan.changes.count
        return .result(
            value: count,
            dialog: "Applied \(count) change\(count == 1 ? "" : "s"). You can undo them from the Sync tab."
        )
    }
}

struct HomeSyncShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PreviewSyncIntent(),
            phrases: [
                "Preview a sync in \(.applicationName)",
                "What would \(.applicationName) change"
            ],
            shortTitle: "Preview Sync",
            systemImageName: "list.bullet.clipboard"
        )
        AppShortcut(
            intent: SyncNowIntent(),
            phrases: [
                "Sync my home with \(.applicationName)",
                "Run a sync in \(.applicationName)"
            ],
            shortTitle: "Sync Now",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
