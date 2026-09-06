import XCTest
@testable import HomeKitBridge

final class HAConfigurationTests: XCTestCase {
    func testWebSocketURLKeepsSchemeAndAddsPath() {
        XCTAssertEqual(
            HAConfiguration.webSocketURL(for: "http://homeassistant.local:8123")?.absoluteString,
            "ws://homeassistant.local:8123/api/websocket"
        )
        XCTAssertEqual(
            HAConfiguration.webSocketURL(for: "https://home.example.com/")?.absoluteString,
            "wss://home.example.com/api/websocket"
        )
        XCTAssertEqual(
            HAConfiguration.webSocketURL(for: "homeassistant.local:8123")?.absoluteString,
            "ws://homeassistant.local:8123/api/websocket"
        )
    }

    func testURLProblems() {
        XCTAssertNotNil(HAConfiguration.urlProblem(""))
        XCTAssertNotNil(HAConfiguration.urlProblem("home assistant.local"))
        XCTAssertNotNil(HAConfiguration.urlProblem("http://homeassistant.local:8123/lovelace/0"))
        XCTAssertNotNil(HAConfiguration.urlProblem("ws://homeassistant.local:8123/api/websocket"))
        XCTAssertNil(HAConfiguration.urlProblem("http://homeassistant.local:8123"))
    }

    func testTokenProblems() {
        XCTAssertNotNil(HAConfiguration.tokenProblem(""))
        XCTAssertNotNil(HAConfiguration.tokenProblem("Bearer abcdefghijklmnopqrstuvwxyz0123456789"))
        XCTAssertNotNil(HAConfiguration.tokenProblem("too-short"))
        XCTAssertNil(HAConfiguration.tokenProblem(String(repeating: "a", count: 180)))
    }
}

final class SyncOperationTests: XCTestCase {
    func testDirectionsNameSourceAndDestination() {
        XCTAssertEqual(SyncOperation.roomsHAToHome.direction.source, .homeAssistant)
        XCTAssertEqual(SyncOperation.roomsHAToHome.direction.destination, .appleHome)
        XCTAssertEqual(SyncOperation.deviceNamesHomeToHA.direction.label, "Apple Home → Home Assistant")
    }

    func testStoredRawValuesFromOlderVersionsStillResolve() {
        XCTAssertEqual(
            SyncOperation.operation(forStoredRawValue: "Sync Placement: HA → Apple Home"),
            .devicePlacementHAToHome
        )
        XCTAssertEqual(
            SyncOperation.operation(forStoredRawValue: "names.appleHomeToHomeAssistant"),
            .deviceNamesHomeToHA
        )
        XCTAssertNil(SyncOperation.operation(forStoredRawValue: "something.removed"))
    }

    func testSummaryNamesTheSideThatChanges() {
        XCTAssertEqual(
            SyncOperation.roomsHAToHome.summary(changeCount: 1),
            "1 room will be created in Apple Home. Home Assistant will not change."
        )
        XCTAssertEqual(
            SyncOperation.roomsHAToHome.summary(changeCount: 0),
            "Apple Home already has a room for every Home Assistant area."
        )
    }
}

final class AccessorySummaryTests: XCTestCase {
    func testEntityIDIsOnlyReadFromHomeAssistantShapedSerials() {
        XCTAssertEqual(
            AccessorySummary(name: "Kitchen", serialNumber: "light.kitchen_ceiling").entityId,
            "light.kitchen_ceiling"
        )
        // A native accessory's hardware serial is not an entity ID.
        XCTAssertNil(AccessorySummary(name: "Lock", serialNumber: "AC-99201-XT").entityId)
        XCTAssertNil(AccessorySummary(name: "Lock", serialNumber: "1.2.3").entityId)
        XCTAssertNil(AccessorySummary(name: "Lock", serialNumber: "Light.Kitchen").entityId)
        XCTAssertNil(AccessorySummary(name: "Lock", serialNumber: "").entityId)
        XCTAssertNil(AccessorySummary(name: "Lock").entityId)
    }
}
