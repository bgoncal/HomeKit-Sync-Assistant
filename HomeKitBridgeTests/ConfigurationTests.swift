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

/// The app once archived without an asset catalog at all: the target had no
/// Resources build phase, so App Store Connect refused every build for having no
/// icon. These assertions run against the host app's real bundle.
final class AppResourcesTests: XCTestCase {
    func testTheAppBundleCarriesItsCompiledAssets() {
        XCTAssertNotNil(
            Bundle.main.url(forResource: "Assets", withExtension: "car"),
            "The asset catalog is missing from the bundle — check the Resources build phase."
        )
    }

    func testTheAppBundleDeclaresAnIcon() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") as? String, "AppIcon")

        #if targetEnvironment(macCatalyst)
        // A Mac bundle carries the icon as a compiled .icns next to the assets.
        XCTAssertNotNil(
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            "No icon was compiled into the Mac bundle; App Store Connect rejects builds without one."
        )
        #else
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let files = primary?["CFBundleIconFiles"] as? [String]
        XCTAssertFalse(
            files?.isEmpty ?? true,
            "No icon was compiled into the bundle; App Store Connect rejects builds without one."
        )
        #endif
    }
}
