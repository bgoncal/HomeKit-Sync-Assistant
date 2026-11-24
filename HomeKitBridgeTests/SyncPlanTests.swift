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
}
