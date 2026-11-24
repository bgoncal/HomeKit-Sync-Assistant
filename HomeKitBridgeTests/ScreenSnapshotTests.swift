import SwiftUI
import XCTest
@testable import HomeKitBridge

@MainActor
final class HomeSnapshotTests: SnapshotTestCase {
    func testBothSidesReady() {
        assertScreen(
            NavigationStack {
                HomeContent(
                    homes: [Fixtures.home, Fixtures.secondHome],
                    isHomeKitAuthorized: true,
                    connections: Fixtures.connections,
                    isServerRunning: true,
                    serverPort: 8400,
                    scheduleCount: 2,
                    supportsScheduledActions: false,
                    tipProduct: Fixtures.tipProduct
                )
            },
            named: "home"
        )
    }

    func testNothingSetUpYet() {
        assertScreen(
            NavigationStack {
                HomeContent(
                    homes: [],
                    isHomeKitAuthorized: false,
                    connections: [],
                    isServerRunning: false,
                    serverPort: 8400,
                    supportsScheduledActions: false,
                    tipProduct: Fixtures.tipProduct
                )
            },
            named: "home-empty"
        )
    }

    /// The Mac also offers scheduled syncs from here.
    func testOnMac() {
        assertScreen(
            NavigationStack {
                HomeContent(
                    homes: [Fixtures.home],
                    isHomeKitAuthorized: true,
                    connections: Fixtures.connectionsWithProblem,
                    isServerRunning: false,
                    serverPort: 8400,
                    scheduleCount: 1,
                    supportsScheduledActions: true,
                    tipProduct: Fixtures.tipProduct,
                    tipState: .thanks
                )
            },
            named: "home-mac"
        )
    }

    func testSettings() {
        assertScreen(
            NavigationStack {
                SettingsContent(tipProduct: Fixtures.tipProduct, appVersion: "1.2 (21)")
            },
            named: "settings"
        )
    }

    func testTheAppleHomeList() {
        assertScreen(
            NavigationStack {
                AppleHomesContent(homes: [Fixtures.home, Fixtures.secondHome])
            },
            named: "apple-homes"
        )
    }

    func testTheHomeAssistantList() {
        assertScreen(
            NavigationStack {
                ServersContent(connections: Fixtures.connectionsWithProblem)
            },
            named: "home-assistants"
        )
    }
}

@MainActor
final class DevicesSnapshotTests: SnapshotTestCase {
    func testDevicesGroupedByRoom() {
        assertScreen(
            NavigationStack {
                HomeDevicesContent(home: Fixtures.home, search: .constant(""))
            },
            named: "home-devices"
        )
    }

    func testNoDevices() {
        assertScreen(
            NavigationStack {
                HomeDevicesContent(home: Fixtures.secondHome, search: .constant(""))
            },
            named: "home-devices-empty"
        )
    }

    func testDeviceMatchedInHomeAssistant() {
        assertScreen(
            NavigationStack {
                DeviceDetailContent(
                    accessory: Fixtures.kitchenLight,
                    matchState: .matched(Fixtures.homeAssistantMatch),
                    serverName: Fixtures.houseServer.name
                )
            },
            named: "device-detail-matched"
        )
    }

    func testDeviceNotBridged() {
        assertScreen(
            NavigationStack {
                DeviceDetailContent(
                    accessory: Fixtures.nativeLock,
                    matchState: .notBridged,
                    serverName: Fixtures.houseServer.name,
                    onChooseEntity: {}
                )
            },
            named: "device-detail-not-bridged"
        )
    }

    /// Picked by hand and left out of syncs: both say so, and both can be undone here.
    func testDevicePairedByHandAndExcluded() {
        assertScreen(
            NavigationStack {
                DeviceDetailContent(
                    accessory: Fixtures.kitchenLight,
                    matchState: .matched(Fixtures.homeAssistantMatch),
                    serverName: Fixtures.houseServer.name,
                    isExcluded: true,
                    isPairedByHand: true,
                    onChooseEntity: {}
                )
            },
            named: "device-detail-by-hand-excluded"
        )
    }

    func testDevicesWithExclusions() {
        assertScreen(
            NavigationStack {
                HomeDevicesContent(
                    home: Fixtures.home,
                    search: .constant(""),
                    excludedAccessoryIds: [Fixtures.kitchenLight.id],
                    excludedRoomNames: [Fixtures.hallwaySensor.roomName.lowercased()],
                    manualEntityIds: [Fixtures.nativeLock.id: "lock.front_door"]
                )
            },
            named: "home-devices-excluded"
        )
    }

    func testExclusions() {
        assertScreen(
            NavigationStack {
                ExclusionsContent(items: [
                    ExclusionItem(id: "room", kind: .room(homeId: Fixtures.home.id, roomName: "Garage"), title: "Garage", subtitle: Fixtures.home.name),
                    ExclusionItem(id: "device", kind: .device(accessoryId: Fixtures.kitchenLight.id), title: Fixtures.kitchenLight.name, subtitle: "\(Fixtures.home.name) · \(Fixtures.kitchenLight.roomName)")
                ])
            },
            named: "exclusions"
        )
    }

    func testNothingExcluded() {
        assertScreen(NavigationStack { ExclusionsContent(items: []) }, named: "exclusions-empty")
    }

    func testEntityPicker() {
        assertScreen(
            NavigationStack {
                EntityPickerContent(
                    serverName: Fixtures.houseServer.name,
                    deviceName: Fixtures.nativeLock.name,
                    areas: Fixtures.entityAreas,
                    selectedEntityId: Fixtures.entityAreas.first?.entities.first?.entityId,
                    search: .constant("")
                )
            },
            named: "entity-picker"
        )
    }

    func testDeviceWithoutAServerToAsk() {
        assertScreen(
            NavigationStack {
                DeviceDetailContent(accessory: Fixtures.hallwaySensor, matchState: .noServer)
            },
            named: "device-detail-no-server"
        )
    }

    func testDeviceServices() {
        assertScreen(
            NavigationStack { DeviceServicesContent(accessory: Fixtures.kitchenLight) },
            named: "device-services"
        )
    }

    func testHomeAssistantRawData() {
        assertScreen(
            NavigationStack { HomeAssistantDataContent(match: Fixtures.homeAssistantMatch) },
            named: "device-raw-data"
        )
    }
}

@MainActor
final class EntitiesSnapshotTests: SnapshotTestCase {
    func testEntitiesGroupedByArea() {
        assertScreen(
            NavigationStack {
                EntitiesContent(
                    serverName: Fixtures.houseServer.name,
                    serverId: Fixtures.houseServer.id,
                    areas: Fixtures.entityAreas,
                    search: .constant("")
                )
            },
            named: "entities"
        )
    }

    func testSearchingEntities() {
        assertScreen(
            NavigationStack {
                EntitiesContent(
                    serverName: Fixtures.houseServer.name,
                    serverId: Fixtures.houseServer.id,
                    areas: Fixtures.entityAreas,
                    search: .constant("light.")
                )
            },
            named: "entities-search"
        )
    }

    func testEntitiesCouldNotBeRead() {
        assertScreen(
            NavigationStack {
                EntitiesContent(
                    serverName: Fixtures.houseServer.name,
                    serverId: Fixtures.houseServer.id,
                    areas: [],
                    state: .failed("Home Assistant rejected the access token: Invalid access token"),
                    search: .constant("")
                )
            },
            named: "entities-failed"
        )
    }
}

@MainActor
final class SyncSnapshotTests: SnapshotTestCase {
    private func sync(
        direction: SyncDirection = .homeAssistantToAppleHome,
        subject: SyncSubject = .placement,
        dryRun: DryRunResult? = nil,
        skipped: Set<UUID> = [],
        lastSync: SyncUndoRecord? = nil,
        progress: SyncProgress? = nil,
        error: String? = nil,
        isWorking: Bool = false
    ) -> some View {
        SyncContent(
            homes: [Fixtures.home, Fixtures.secondHome],
            servers: [Fixtures.houseServer, Fixtures.beachServer],
            homeId: .constant(Fixtures.home.id),
            serverId: .constant(Fixtures.houseServer.id),
            direction: .constant(direction),
            subject: .constant(subject),
            dryRunResult: dryRun,
            skippedChangeIds: .constant(skipped),
            lastSync: lastSync,
            progress: progress,
            errorMessage: error,
            isWorking: isWorking
        )
    }

    func testTheStepsBeforeAnyPreview() {
        assertScreen(NavigationStack { sync() }, named: "sync")
    }

    func testTheOtherDirection() {
        assertScreen(
            NavigationStack { sync(direction: .appleHomeToHomeAssistant, subject: .names) },
            named: "sync-reversed"
        )
    }

    func testPreviewWithChanges() {
        assertScreen(NavigationStack { sync(dryRun: Fixtures.placementPreview) }, named: "sync-preview")
    }

    /// Unticked changes stay in the list, greyed, and drop out of the Apply count.
    func testPreviewWithSomeChangesUnticked() {
        let skipped = Set(Fixtures.placementPreview.changes.prefix(1).map(\.id))
        assertScreen(
            NavigationStack { sync(dryRun: Fixtures.placementPreview, skipped: skipped) },
            named: "sync-preview-partial"
        )
    }

    func testUndoAfterASync() {
        assertScreen(NavigationStack { sync(lastSync: Fixtures.lastSync) }, named: "sync-undo")
    }

    func testAlreadyInSync() {
        assertScreen(
            NavigationStack { sync(subject: .names, dryRun: Fixtures.upToDatePreview) },
            named: "sync-already-in-sync"
        )
    }

    func testApplying() {
        assertScreen(
            NavigationStack { sync(dryRun: Fixtures.placementPreview, progress: Fixtures.runningProgress, isWorking: true) },
            named: "sync-applying"
        )
    }

    func testSyncFailed() {
        assertScreen(
            NavigationStack { sync(error: "Home Assistant rejected the access token: Invalid access token") },
            named: "sync-failed"
        )
    }
}

@MainActor
final class DifferencesSnapshotTests: SnapshotTestCase {
    func testDifferences() {
        assertScreen(NavigationStack { DifferencesContent(state: .loaded(Fixtures.differences)) }, named: "differences")
    }

    func testEverythingMatches() {
        let inSync = PairDifferences(homeName: Fixtures.home.name, serverName: Fixtures.houseServer.name, matchingCount: 3)
        assertScreen(NavigationStack { DifferencesContent(state: .loaded(inSync)) }, named: "differences-in-sync")
    }

    func testComparing() {
        assertScreen(NavigationStack { DifferencesContent(state: .loading) }, named: "differences-loading")
    }

    func testCouldNotCompare() {
        assertScreen(
            NavigationStack { DifferencesContent(state: .failed("Home Assistant rejected the access token: Invalid access token")) },
            named: "differences-failed"
        )
    }
}

@MainActor
final class ActionsSnapshotTests: SnapshotTestCase {
    func testNoScheduledActions() {
        assertScreen(NavigationStack { ActionsContent(schedules: []) }, named: "actions-empty")
    }

    func testScheduledActions() {
        assertScreen(
            NavigationStack {
                ActionsContent(
                    schedules: Fixtures.schedules,
                    homes: [Fixtures.home, Fixtures.secondHome],
                    servers: [Fixtures.houseServer, Fixtures.beachServer],
                    suggestedServerIds: [Fixtures.home.id: Fixtures.houseServer.id]
                )
            },
            named: "actions-scheduled"
        )
    }
}

@MainActor
final class LocalAPISnapshotTests: SnapshotTestCase {
    func testRunning() {
        assertScreen(
            NavigationStack {
                LocalAPIContent(isRunning: true, port: .constant(8400), autoStart: .constant(true))
            },
            named: "local-api"
        )
    }

    func testStopped() {
        assertScreen(
            NavigationStack {
                LocalAPIContent(isRunning: false, port: .constant(8400), autoStart: .constant(false))
            },
            named: "local-api-stopped"
        )
    }

    func testEndpointDetail() {
        assertScreen(
            NavigationStack { EndpointDetailContent(endpoint: EndpointInfo.all[4]) },
            named: "endpoint-detail"
        )
    }
}

@MainActor
final class ServerDetailSnapshotTests: SnapshotTestCase {
    func testConfiguredServer() {
        assertScreen(
            NavigationStack {
                ServerDetailContent(server: .constant(Fixtures.houseServer), connectionState: .succeeded)
            },
            named: "server-detail"
        )
    }

    func testNewServerWithInvalidCredentials() {
        assertScreen(
            NavigationStack {
                ServerDetailContent(
                    server: .constant(HomeAssistantServer(name: "Studio", address: "studio.local:8123/lovelace/0", token: "Bearer abc")),
                    isNew: true,
                    connectionState: .failed("Could not connect. Check the address and token, then try again.")
                )
            },
            named: "server-detail-new"
        )
    }
}

@MainActor
final class LogsSnapshotTests: SnapshotTestCase {
    func testActivityWithEntries() {
        assertScreen(
            NavigationStack {
                LogsContent(
                    entries: Fixtures.logEntries,
                    search: .constant(""),
                    selectedCategory: .constant(.all)
                )
            },
            named: "activity"
        )
    }

    func testEmptyActivity() {
        assertScreen(
            NavigationStack {
                LogsContent(entries: [], search: .constant(""), selectedCategory: .constant(.all))
            },
            named: "activity-empty"
        )
    }
}
