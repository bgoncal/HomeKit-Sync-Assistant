import SwiftUI
import XCTest
@testable import HomeKitBridge

@MainActor
final class DashboardSnapshotTests: SnapshotTestCase {
    func testEverythingConnected() {
        assertScreen(
            DashboardContent(
                isHomeKitAuthorized: true,
                home: Fixtures.home,
                isHomeAssistantConnected: true,
                homeAssistantError: nil,
                homeAssistantAddress: "http://homeassistant.local:8123",
                isServerRunning: true,
                serverPort: 8400
            ),
            named: "dashboard-connected"
        )
    }

    func testHomeAssistantDisconnected() {
        assertScreen(
            DashboardContent(
                isHomeKitAuthorized: true,
                home: Fixtures.home,
                isHomeAssistantConnected: false,
                homeAssistantError: "Home Assistant rejected the access token: Invalid access token",
                homeAssistantAddress: "http://homeassistant.local:8123",
                isServerRunning: false,
                serverPort: 8400
            ),
            named: "dashboard-home-assistant-disconnected"
        )
    }

    func testWaitingForHomeKitAccess() {
        assertScreen(
            DashboardContent(
                isHomeKitAuthorized: false,
                home: nil,
                isHomeAssistantConnected: false,
                homeAssistantError: nil,
                homeAssistantAddress: "",
                isServerRunning: false,
                serverPort: 8400
            ),
            named: "dashboard-no-access"
        )
    }
}

@MainActor
final class DevicesSnapshotTests: SnapshotTestCase {
    func testDeviceList() {
        assertScreen(
            NavigationStack {
                DevicesContent(homes: [Fixtures.home, Fixtures.secondHome], selectedHomeId: Fixtures.home.id)
            },
            named: "devices-list"
        )
    }

    func testEmptyDeviceList() {
        assertScreen(
            NavigationStack {
                DevicesContent(homes: [], selectedHomeId: nil)
            },
            named: "devices-empty"
        )
    }

    func testDeviceMatchedInHomeAssistant() {
        assertScreen(
            DeviceDetailContent(accessory: Fixtures.kitchenLight, matchState: .matched(Fixtures.homeAssistantMatch)),
            named: "device-detail-matched"
        )
    }

    func testDeviceNotBridged() {
        assertScreen(
            DeviceDetailContent(accessory: Fixtures.nativeLock, matchState: .notBridged),
            named: "device-detail-not-bridged"
        )
    }

    func testDeviceLookupFailed() {
        assertScreen(
            DeviceDetailContent(
                accessory: Fixtures.hallwaySensor,
                matchState: .failed("Not connected to Home Assistant")
            ),
            named: "device-detail-failed"
        )
    }
}

@MainActor
final class SyncSnapshotTests: SnapshotTestCase {
    func testNoPreviewYet() {
        assertScreen(
            SyncContent(
                homes: [Fixtures.home, Fixtures.secondHome],
                selectedHomeId: Fixtures.home.id,
                operation: .constant(.devicePlacementHAToHome),
                dryRunResult: nil,
                progress: nil,
                errorMessage: nil,
                isWorking: false
            ),
            named: "sync-no-preview"
        )
    }

    func testPreviewWithChanges() {
        assertScreen(
            SyncContent(
                homes: [Fixtures.home],
                selectedHomeId: Fixtures.home.id,
                operation: .constant(.devicePlacementHAToHome),
                dryRunResult: Fixtures.placementPreview,
                progress: nil,
                errorMessage: nil,
                isWorking: false
            ),
            named: "sync-preview-changes"
        )
    }

    func testAlreadyInSync() {
        assertScreen(
            SyncContent(
                homes: [Fixtures.home],
                selectedHomeId: Fixtures.home.id,
                operation: .constant(.deviceNamesHomeToHA),
                dryRunResult: Fixtures.upToDatePreview,
                progress: nil,
                errorMessage: nil,
                isWorking: false
            ),
            named: "sync-already-in-sync"
        )
    }

    func testApplyingChanges() {
        assertScreen(
            SyncContent(
                homes: [Fixtures.home],
                selectedHomeId: Fixtures.home.id,
                operation: .constant(.devicePlacementHAToHome),
                dryRunResult: Fixtures.placementPreview,
                progress: Fixtures.runningProgress,
                errorMessage: nil,
                isWorking: true
            ),
            named: "sync-applying"
        )
    }

    func testSyncError() {
        assertScreen(
            SyncContent(
                homes: [],
                selectedHomeId: nil,
                operation: .constant(.roomsHAToHome),
                dryRunResult: nil,
                progress: nil,
                errorMessage: "No Apple Home is available yet. Grant HomeKit access, then pick a home.",
                isWorking: false
            ),
            named: "sync-error"
        )
    }
}

@MainActor
final class ActionsSnapshotTests: SnapshotTestCase {
    func testNoScheduledActions() {
        assertScreen(ActionsContent(schedules: []), named: "actions-empty")
    }

    func testScheduledActions() {
        assertScreen(ActionsContent(schedules: Fixtures.schedules), named: "actions-scheduled")
    }
}

@MainActor
final class EndpointsSnapshotTests: SnapshotTestCase {
    func testLocalAPIReference() {
        assertScreen(EndpointsView(), named: "endpoints")
    }
}

@MainActor
final class SettingsSnapshotTests: SnapshotTestCase {
    func testConfiguredSettings() {
        assertScreen(
            SettingsContent(
                haURL: .constant("http://homeassistant.local:8123"),
                haToken: .constant(Fixtures.token),
                connectionState: .succeeded,
                serverPort: .constant(8400),
                autoStartServer: .constant(true),
                isServerRunning: true
            ),
            named: "settings-configured"
        )
    }

    func testSettingsWithInvalidCredentials() {
        assertScreen(
            SettingsContent(
                haURL: .constant("homeassistant.local:8123/lovelace/0"),
                haToken: .constant("Bearer abc"),
                connectionState: .failed("Could not connect. Check the address and token, then try again."),
                serverPort: .constant(8400),
                autoStartServer: .constant(false),
                isServerRunning: false
            ),
            named: "settings-invalid"
        )
    }
}

@MainActor
final class LogsSnapshotTests: SnapshotTestCase {
    func testActivityWithEntries() {
        assertScreen(
            LogsContent(
                entries: Fixtures.logEntries,
                search: .constant(""),
                selectedCategory: .constant(.all)
            ),
            named: "activity-entries"
        )
    }

    func testEmptyActivity() {
        assertScreen(
            LogsContent(
                entries: [],
                search: .constant(""),
                selectedCategory: .constant(.all)
            ),
            named: "activity-empty"
        )
    }
}
