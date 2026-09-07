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
                    serverName: Fixtures.houseServer.name
                )
            },
            named: "device-detail-not-bridged"
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
