import SwiftUI
import XCTest
@testable import HomeKitBridge

@MainActor
final class DashboardSnapshotTests: SnapshotTestCase {
    func testTwoHomesAndTwoServers() {
        assertScreen(
            NavigationStack {
                DashboardContent(
                    isHomeKitAuthorized: true,
                    homes: [Fixtures.home, Fixtures.secondHome],
                    connections: Fixtures.connections,
                    isServerRunning: true,
                    serverPort: 8400
                )
            },
            named: "dashboard-connected"
        )
    }

    func testServerFailedAndHomeNotLinked() {
        assertScreen(
            NavigationStack {
                DashboardContent(
                    isHomeKitAuthorized: true,
                    homes: [Fixtures.home, Fixtures.secondHome],
                    connections: Fixtures.connectionsWithProblem,
                    unlinkedHomes: [Fixtures.secondHome],
                    isServerRunning: false,
                    serverPort: 8400
                )
            },
            named: "dashboard-home-assistant-disconnected"
        )
    }

    func testWaitingForHomeKitAccess() {
        assertScreen(
            NavigationStack {
                DashboardContent(
                    isHomeKitAuthorized: false,
                    homes: [],
                    connections: [],
                    isServerRunning: false,
                    serverPort: 8400
                )
            },
            named: "dashboard-no-access"
        )
    }
}

@MainActor
final class DevicesSnapshotTests: SnapshotTestCase {
    func testDeviceList() {
        assertScreen(
            NavigationStack {
                DevicesContent(
                    homes: [Fixtures.home, Fixtures.secondHome],
                    selectedHomeId: Fixtures.home.id,
                    search: .constant("")
                )
            },
            named: "devices-list"
        )
    }

    func testEmptyDeviceList() {
        assertScreen(
            NavigationStack {
                DevicesContent(homes: [], selectedHomeId: nil, search: .constant(""))
            },
            named: "devices-empty"
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

    func testDeviceLookupFailed() {
        assertScreen(
            NavigationStack {
                DeviceDetailContent(
                    accessory: Fixtures.hallwaySensor,
                    matchState: .failed("Not connected to House"),
                    serverName: Fixtures.houseServer.name
                )
            },
            named: "device-detail-failed"
        )
    }

    func testDeviceServices() {
        assertScreen(
            NavigationStack {
                DeviceServicesContent(accessory: Fixtures.kitchenLight)
            },
            named: "device-services"
        )
    }

    func testHomeAssistantRawData() {
        assertScreen(
            NavigationStack {
                HomeAssistantDataContent(match: Fixtures.homeAssistantMatch)
            },
            named: "device-raw-data"
        )
    }
}

@MainActor
final class SyncSnapshotTests: SnapshotTestCase {
    func testNoPreviewYet() {
        assertScreen(
            NavigationStack {
                SyncContent(
                    homes: [Fixtures.home, Fixtures.secondHome],
                    selectedHomeId: Fixtures.home.id,
                    serverName: Fixtures.houseServer.name,
                    serverState: .connected,
                    operation: .constant(.devicePlacementHAToHome),
                    dryRunResult: nil,
                    progress: nil,
                    errorMessage: nil,
                    isWorking: false
                )
            },
            named: "sync-no-preview"
        )
    }

    func testPreviewWithChanges() {
        assertScreen(
            NavigationStack {
                SyncContent(
                    homes: [Fixtures.home],
                    selectedHomeId: Fixtures.home.id,
                    serverName: Fixtures.houseServer.name,
                    serverState: .connected,
                    operation: .constant(.devicePlacementHAToHome),
                    dryRunResult: Fixtures.placementPreview,
                    progress: nil,
                    errorMessage: nil,
                    isWorking: false
                )
            },
            named: "sync-preview-changes"
        )
    }

    func testAlreadyInSync() {
        assertScreen(
            NavigationStack {
                SyncContent(
                    homes: [Fixtures.home],
                    selectedHomeId: Fixtures.home.id,
                    serverName: Fixtures.houseServer.name,
                    serverState: .connected,
                    operation: .constant(.deviceNamesHomeToHA),
                    dryRunResult: Fixtures.upToDatePreview,
                    progress: nil,
                    errorMessage: nil,
                    isWorking: false
                )
            },
            named: "sync-already-in-sync"
        )
    }

    func testApplyingChanges() {
        assertScreen(
            NavigationStack {
                SyncContent(
                    homes: [Fixtures.home],
                    selectedHomeId: Fixtures.home.id,
                    serverName: Fixtures.houseServer.name,
                    serverState: .connected,
                    operation: .constant(.devicePlacementHAToHome),
                    dryRunResult: Fixtures.placementPreview,
                    progress: Fixtures.runningProgress,
                    errorMessage: nil,
                    isWorking: false
                )
            },
            named: "sync-applying"
        )
    }

    func testSyncError() {
        assertScreen(
            NavigationStack {
                SyncContent(
                    homes: [Fixtures.home],
                    selectedHomeId: Fixtures.home.id,
                    serverName: nil,
                    serverState: nil,
                    operation: .constant(.roomsHAToHome),
                    dryRunResult: nil,
                    progress: nil,
                    errorMessage: "“Casa” is not linked to a Home Assistant server yet. Link it in Settings.",
                    isWorking: false
                )
            },
            named: "sync-not-linked"
        )
    }
}

@MainActor
final class ActionsSnapshotTests: SnapshotTestCase {
    func testNoScheduledActions() {
        assertScreen(
            NavigationStack { ActionsContent(schedules: []) },
            named: "actions-empty"
        )
    }

    func testScheduledActions() {
        assertScreen(
            NavigationStack {
                ActionsContent(
                    schedules: Fixtures.schedules,
                    homes: [Fixtures.home, Fixtures.secondHome],
                    serverNames: [Fixtures.home.id: Fixtures.houseServer.name, Fixtures.secondHome.id: Fixtures.beachServer.name]
                )
            },
            named: "actions-scheduled"
        )
    }
}

@MainActor
final class EndpointsSnapshotTests: SnapshotTestCase {
    func testLocalAPIReference() {
        assertScreen(
            NavigationStack { EndpointsContent(port: 8400, isRunning: true) },
            named: "endpoints"
        )
    }

    func testEndpointDetail() {
        assertScreen(
            NavigationStack {
                EndpointDetailContent(endpoint: EndpointInfo.all[4])
            },
            named: "endpoint-detail"
        )
    }
}

@MainActor
final class SettingsSnapshotTests: SnapshotTestCase {
    func testTwoServersOnMac() {
        assertScreen(
            NavigationStack {
                SettingsContent(
                    connections: Fixtures.connections,
                    homes: [Fixtures.home, Fixtures.secondHome],
                    serverPort: .constant(8400),
                    autoStartServer: .constant(true),
                    isServerRunning: true,
                    scheduleCount: 2,
                    supportsScheduledActions: true
                )
            },
            named: "settings-mac"
        )
    }

    /// iPhone and iPad have no scheduled syncs at all; the section is absent.
    func testNoScheduledSyncsOnPhone() {
        assertScreen(
            NavigationStack {
                SettingsContent(
                    connections: Fixtures.connectionsWithProblem,
                    homes: [Fixtures.home, Fixtures.secondHome],
                    serverPort: .constant(8400),
                    autoStartServer: .constant(false),
                    isServerRunning: false,
                    supportsScheduledActions: false
                )
            },
            named: "settings-phone"
        )
    }

    func testWithoutICloud() {
        assertScreen(
            NavigationStack {
                SettingsContent(
                    connections: Fixtures.connections,
                    homes: [Fixtures.home, Fixtures.secondHome],
                    isSyncingWithCloud: false,
                    serverPort: .constant(8400),
                    autoStartServer: .constant(true),
                    isServerRunning: true,
                    supportsScheduledActions: false
                )
            },
            named: "settings-no-icloud"
        )
    }

    func testNoServersYet() {
        assertScreen(
            NavigationStack {
                SettingsContent(
                    connections: [],
                    homes: [Fixtures.home],
                    serverPort: .constant(8400),
                    autoStartServer: .constant(true),
                    isServerRunning: false,
                    supportsScheduledActions: false
                )
            },
            named: "settings-no-servers"
        )
    }
}

@MainActor
final class ServerDetailSnapshotTests: SnapshotTestCase {
    func testConfiguredServer() {
        assertScreen(
            NavigationStack {
                ServerDetailContent(
                    server: .constant(Fixtures.houseServer),
                    homes: [Fixtures.home, Fixtures.secondHome],
                    connectionState: .succeeded
                )
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
                    homes: [Fixtures.home],
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
            named: "activity-entries"
        )
    }

    func testEmptyActivity() {
        assertScreen(
            NavigationStack {
                LogsContent(
                    entries: [],
                    search: .constant(""),
                    selectedCategory: .constant(.all)
                )
            },
            named: "activity-empty"
        )
    }
}
