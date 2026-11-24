import XCTest
@testable import HomeKitBridge

final class SyncPlanTests: XCTestCase {
    /// Unticking a change in the preview must not move the plan to another pair.
    func testKeepingFiltersChangesAndKeepsThePair() {
        let plan = Fixtures.placementPreview
        let kept = plan.keeping { $0.action == .moveAccessory }

        XCTAssertEqual(kept.changes.map(\.action), [.moveAccessory])
        XCTAssertEqual(kept.id, plan.id)
        XCTAssertEqual(kept.homeId, plan.homeId)
        XCTAssertEqual(kept.serverId, plan.serverId)
        XCTAssertEqual(kept.operation, plan.operation)
    }

    /// The record is stored as JSON in UserDefaults; its shape is persisted API.
    func testUndoRecordRoundTripsThroughDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SyncPlanTests"))
        defaults.removePersistentDomain(forName: "SyncPlanTests")

        SyncUndoRecord.save(Fixtures.lastSync, to: defaults)
        XCTAssertEqual(SyncUndoRecord.load(from: defaults), Fixtures.lastSync)

        SyncUndoRecord.save(nil, to: defaults)
        XCTAssertNil(SyncUndoRecord.load(from: defaults))
    }

    func testAnUndoExpiresAfterADay() {
        let record = Fixtures.lastSync
        XCTAssertFalse(record.isExpired(now: record.date.addingTimeInterval(60 * 60)))
        XCTAssertTrue(record.isExpired(now: record.date.addingTimeInterval(25 * 60 * 60)))
    }

    // MARK: Scenes

    func testBrightnessConvertsBetween255And100() {
        let action = SyncEngine.sceneAction(accessoryId: "a", homeAssistantState: ["state": "on", "brightness": 128])
        XCTAssertEqual(action, SceneAction(accessoryId: "a", isOn: true, brightness: 50))

        let state = SyncEngine.homeAssistantState(for: SceneAction(accessoryId: "a", isOn: true, brightness: 50), entityId: "light.kitchen")
        XCTAssertEqual(state["state"] as? String, "on")
        XCTAssertEqual(state["brightness"] as? Int, 128)
    }

    /// Only on and off mean the same thing on both sides; anything else stays behind.
    func testStatesThatAreNotOnOrOffAreLeftOut() {
        XCTAssertNil(SyncEngine.sceneAction(accessoryId: "a", homeAssistantState: ["state": "open"]))
        XCTAssertEqual(
            SyncEngine.sceneAction(accessoryId: "a", homeAssistantState: ["state": "off", "brightness": 200]),
            SceneAction(accessoryId: "a", isOn: false)
        )
    }

    func testSwitchesNeverGetABrightness() {
        let state = SyncEngine.homeAssistantState(for: SceneAction(accessoryId: "a", isOn: true, brightness: 80), entityId: "switch.fan")
        XCTAssertNil(state["brightness"])
    }

    /// Stored scheduled syncs name operations by raw value; new ones must not reuse old names.
    func testOperationRawValuesAreUniqueAndRoundTrip() {
        let raw = SyncOperation.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raw).count, raw.count)
        for operation in SyncOperation.allCases {
            XCTAssertEqual(SyncOperation.operation(forStoredRawValue: operation.rawValue), operation)
            XCTAssertEqual(operation.inverted.inverted, operation)
            XCTAssertEqual(operation.direction.operation(for: operation.subject), operation)
        }
    }
}
