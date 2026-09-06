import Foundation
import SwiftUI
@testable import HomeKitBridge

/// Stable sample data every snapshot test renders from. Nothing here touches
/// HomeKit or Home Assistant, so the screens render identically on every run.
enum Fixtures {
    static let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.sample-long-lived-token-value"

    static let kitchenLight = AccessorySummary(
        id: "11111111-1111-1111-1111-111111111111",
        name: "Kitchen Ceiling",
        roomId: "aaaaaaaa-0000-0000-0000-000000000001",
        roomName: "Kitchen",
        manufacturer: "Home Assistant",
        model: "Bridged Light",
        category: "Light Bulb",
        isReachable: true,
        serialNumber: "light.kitchen_ceiling",
        services: [
            ServiceSummary(
                id: "s1",
                name: "Kitchen Ceiling",
                type: "public.hap.service.lightbulb",
                characteristics: [
                    CharacteristicSummary(id: "c1", type: "public.hap.characteristic.on", value: "1"),
                    CharacteristicSummary(id: "c2", type: "public.hap.characteristic.brightness", value: "80")
                ]
            )
        ]
    )

    static let hallwaySensor = AccessorySummary(
        id: "22222222-2222-2222-2222-222222222222",
        name: "Hallway Motion",
        roomId: "aaaaaaaa-0000-0000-0000-000000000002",
        roomName: "Hallway",
        manufacturer: "Home Assistant",
        model: "Bridged Sensor",
        category: "Sensor",
        isReachable: false,
        serialNumber: "binary_sensor.hallway_motion"
    )

    static let nativeLock = AccessorySummary(
        id: "33333333-3333-3333-3333-333333333333",
        name: "Front Door",
        roomId: "aaaaaaaa-0000-0000-0000-000000000003",
        roomName: "Entrance",
        manufacturer: "Acme",
        model: "Smart Lock 2",
        category: "Lock",
        isReachable: true,
        isBridged: false,
        serialNumber: "AC-99201-XT"
    )

    static let home = HomeSummary(
        id: "00000000-0000-0000-0000-0000000000aa",
        name: "Casa",
        rooms: [
            RoomSummary(id: "aaaaaaaa-0000-0000-0000-000000000001", name: "Kitchen"),
            RoomSummary(id: "aaaaaaaa-0000-0000-0000-000000000002", name: "Hallway"),
            RoomSummary(id: "aaaaaaaa-0000-0000-0000-000000000003", name: "Entrance")
        ],
        accessories: [kitchenLight, hallwaySensor, nativeLock]
    )

    static let secondHome = HomeSummary(
        id: "00000000-0000-0000-0000-0000000000bb",
        name: "Beach House"
    )

    // MARK: - Servers

    static let houseServer = HomeAssistantServer(
        id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
        name: "House",
        address: "http://homeassistant.local:8123",
        token: token,
        linkedHomeIds: [home.id]
    )

    static let beachServer = HomeAssistantServer(
        id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!,
        name: "Beach House",
        address: "http://beach.local:8123",
        token: token,
        linkedHomeIds: [secondHome.id]
    )

    /// A server that has been added but never reached.
    static let unreachableServer = HomeAssistantServer(
        id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000003")!,
        name: "Studio",
        address: "http://studio.local:8123",
        token: token
    )

    static let connections: [ConnectionSummary] = [
        ConnectionSummary(server: houseServer, state: .connected, linkedHomes: [home]),
        ConnectionSummary(server: beachServer, state: .connected, linkedHomes: [secondHome])
    ]

    static let connectionsWithProblem: [ConnectionSummary] = [
        ConnectionSummary(server: houseServer, state: .connected, linkedHomes: [home]),
        ConnectionSummary(
            server: unreachableServer,
            state: .failed("Home Assistant rejected the access token: Invalid access token"),
            linkedHomes: []
        )
    ]

    static let homeAssistantMatch = HomeAssistantMatch(
        entityId: "light.kitchen_ceiling",
        friendlyName: "Kitchen Ceiling Light",
        areaName: "Cozinha",
        deviceId: "5f2a1c9d",
        serverName: "House",
        stateJSON: """
        {
          "entity_id" : "light.kitchen_ceiling",
          "state" : "on"
        }
        """,
        entityJSON: """
        {
          "area_id" : "cozinha",
          "entity_id" : "light.kitchen_ceiling"
        }
        """
    )

    // MARK: - Sync

    static let placementPreview = DryRunResult(
        id: UUID(uuidString: "DDDDDDDD-0000-0000-0000-000000000001")!,
        operation: .devicePlacementHAToHome,
        homeId: home.id,
        summary: SyncOperation.devicePlacementHAToHome.summary(changeCount: 2),
        changes: [
            SyncChange(
                id: UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000001")!,
                action: .createRoom,
                title: "Create “Cozinha” in Apple Home",
                details: "Needed before devices can be moved into it.",
                newName: "Cozinha",
                homeId: home.id,
                targetRoomName: "Cozinha"
            ),
            SyncChange(
                id: UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000002")!,
                action: .moveAccessory,
                title: "Move “Kitchen Ceiling” in Apple Home",
                details: "Apple Home room Kitchen → Cozinha, to match its Home Assistant area.",
                accessoryId: kitchenLight.id,
                targetRoomName: "Cozinha",
                extraData: ["Home Assistant entity": "light.kitchen_ceiling"]
            )
        ]
    )

    static let upToDatePreview = DryRunResult(
        id: UUID(uuidString: "DDDDDDDD-0000-0000-0000-000000000002")!,
        operation: .deviceNamesHomeToHA,
        homeId: home.id,
        summary: SyncOperation.deviceNamesHomeToHA.summary(changeCount: 0),
        changes: []
    )

    static let runningProgress = SyncProgress(
        title: "Applying change 2 of 5",
        detail: "Move “Kitchen Ceiling” in Apple Home",
        completed: 2,
        total: 5
    )

    // MARK: - Actions

    static let schedules: [ScheduledAction] = [
        ScheduledAction(
            id: UUID(uuidString: "EEEEEEEE-0000-0000-0000-000000000001")!,
            isEnabled: true,
            timeMinutes: 7 * 60 + 30,
            operationRawValue: SyncOperation.devicePlacementHAToHome.rawValue,
            homeId: home.id
        ),
        ScheduledAction(
            id: UUID(uuidString: "EEEEEEEE-0000-0000-0000-000000000002")!,
            isEnabled: false,
            timeMinutes: 22 * 60,
            operationRawValue: SyncOperation.deviceNamesHomeToHA.rawValue,
            homeId: home.id
        )
    ]

    // MARK: - Activity

    private static let referenceDate = Date(timeIntervalSince1970: 1_760_000_000)

    static let logEntries: [LogEntry] = [
        LogEntry(
            id: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001")!,
            timestamp: referenceDate,
            category: .sync,
            message: "Finished: Move Apple Home devices into their Home Assistant areas",
            details: "4 applied, 0 failed in Apple Home"
        ),
        LogEntry(
            id: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000002")!,
            timestamp: referenceDate.addingTimeInterval(-120),
            category: .server,
            message: "Local API started",
            details: "Port 8400"
        ),
        LogEntry(
            id: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000003")!,
            timestamp: referenceDate.addingTimeInterval(-600),
            category: .error,
            message: "Could not reach Home Assistant",
            details: "Home Assistant rejected the access token: Invalid access token"
        )
    ]

}
