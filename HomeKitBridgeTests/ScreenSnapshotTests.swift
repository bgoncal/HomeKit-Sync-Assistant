import SwiftUI
import XCTest
@testable import HomeKitBridge

@MainActor
final class DashboardSnapshotTests: SnapshotTestCase {
    func testEverythingConnected() {
        assertScreen(
            NavigationStack {
                DashboardContent(
                    isHomeKitAuthorized: true,
                    home: Fixtures.home,
                    isHomeAssistantConnected: true,
                    homeAssistantError: nil,
                    homeAssistantAddress: "http://homeassistant.local:8123",
                    isServerRunning: true,
                    serverPort: 8400
                )
            },
            named: "dashboard-connected"
        )
    }

    func testHomeAssistantDisconnected() {
        assertScreen(
            NavigationStack {
                DashboardContent(
                    isHomeKitAuthorized: true,
                    home: Fixtures.home,
                    isHomeAssistantConnected: false,
                    homeAssistantError: "Home Assistant rejected the access token: Invalid access token",
                    homeAssistantAddress: "http://homeassistant.local:8123",
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
                    home: nil,
                    isHomeAssistantConnected: false,
                    homeAssistantError: nil,
                    homeAssistantAddress: "",
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
                DeviceDetailContent(accessory: Fixtures.kitchenLight, matchState: .matched(Fixtures.homeAssistantMatch))
            },
            named: "device-detail-matched"
        )
    }

    func testDeviceNotBridged() {
        assertScreen(
            NavigationStack {
                DeviceDetailContent(accessory: Fixtures.nativeLock, matchState: .notBridged)
            },
            named: "device-detail-not-bridged"
        )
    }

    func testDeviceLookupFailed() {
        assertScreen(
            NavigationStack {
                DeviceDetailContent(
                    accessory: Fixtures.hallwaySensor,
                    matchState: .failed("Not connected to Home Assistant")
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
                    scheduleCount: 0,
                    homes: [Fixtures.home, Fixtures.secondHome],
                    selectedHomeId: Fixtures.home.id,
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
                    scheduleCount: 2,
                    homes: [Fixtures.home],
                    selectedHomeId: Fixtures.home.id,
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
                    scheduleCount: 0,
                    homes: [Fixtures.home],
                    selectedHomeId: Fixtures.home.id,
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
                    scheduleCount: 0,
                    homes: [Fixtures.home],
                    selectedHomeId: Fixtures.home.id,
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
                    scheduleCount: 0,
                    homes: [],
                    selectedHomeId: nil,
                    operation: .constant(.roomsHAToHome),
                    dryRunResult: nil,
                    progress: nil,
                    errorMessage: "No Apple Home is available yet. Grant HomeKit access, then pick a home.",
                    isWorking: false
                )
            },
            named: "sync-error"
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
            NavigationStack { ActionsContent(schedules: Fixtures.schedules) },
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
    func testConfiguredSettings() {
        assertScreen(
            NavigationStack {
                SettingsContent(
                    haURL: .constant("http://homeassistant.local:8123"),
                    haToken: .constant(Fixtures.token),
                    connectionState: .succeeded,
                    serverPort: .constant(8400),
                    autoStartServer: .constant(true),
                    isServerRunning: true
                )
            },
            named: "settings-configured"
        )
    }

    func testSettingsWithInvalidCredentials() {
        assertScreen(
            NavigationStack {
                SettingsContent(
                    haURL: .constant("homeassistant.local:8123/lovelace/0"),
                    haToken: .constant("Bearer abc"),
                    connectionState: .failed("Could not connect. Check the address and token, then try again."),
                    serverPort: .constant(8400),
                    autoStartServer: .constant(false),
                    isServerRunning: false
                )
            },
            named: "settings-invalid"
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
