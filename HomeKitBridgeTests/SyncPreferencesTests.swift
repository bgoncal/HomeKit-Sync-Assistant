import XCTest
@testable import HomeKitBridge

final class SyncPreferencesPayloadTests: XCTestCase {
    private let early = Date(timeIntervalSince1970: 1_000)
    private let late = Date(timeIntervalSince1970: 2_000)

    func testTheNewerEntryWinsEitherWayRound() {
        let local = SyncPreferencesPayload(manualPairings: ["a": PreferenceEntry(value: "light.one", updatedAt: early)])
        let remote = SyncPreferencesPayload(manualPairings: ["a": PreferenceEntry(value: "light.two", updatedAt: late)])

        XCTAssertEqual(SyncPreferencesPayload.merged(local, remote).manualPairings["a"]?.value, "light.two")
        XCTAssertEqual(SyncPreferencesPayload.merged(remote, local).manualPairings["a"]?.value, "light.two")
    }

    /// A removal made later is not undone by an older device that still has the entry.
    func testALaterRemovalBeatsAnOlderValue() {
        let local = SyncPreferencesPayload(excludedAccessories: ["a": PreferenceEntry(value: nil, updatedAt: late)])
        let remote = SyncPreferencesPayload(excludedAccessories: ["a": PreferenceEntry(value: "1", updatedAt: early)])

        XCTAssertNil(SyncPreferencesPayload.merged(local, remote).excludedAccessories["a"]?.value)
        XCTAssertNil(SyncPreferencesPayload.merged(remote, local).excludedAccessories["a"]?.value)
    }

    func testMergingIsCommutativeAndIdempotentOnATie() {
        let one = SyncPreferencesPayload(excludedRooms: ["h|kitchen": PreferenceEntry(value: "Kitchen", updatedAt: early)])
        let two = SyncPreferencesPayload(excludedRooms: ["h|kitchen": PreferenceEntry(value: nil, updatedAt: early)])

        let merged = SyncPreferencesPayload.merged(one, two)
        XCTAssertEqual(merged, SyncPreferencesPayload.merged(two, one))
        XCTAssertEqual(SyncPreferencesPayload.merged(merged, merged), merged)
    }

    func testKeysFromBothSidesAreKept() {
        let local = SyncPreferencesPayload(manualPairings: ["a": PreferenceEntry(value: "light.one", updatedAt: early)])
        let remote = SyncPreferencesPayload(manualPairings: ["b": PreferenceEntry(value: "lock.two", updatedAt: early)])

        XCTAssertEqual(Set(SyncPreferencesPayload.merged(local, remote).manualPairings.keys), ["a", "b"])
    }
}

@MainActor
final class SyncPreferencesStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SyncPreferencesStoreTests")
        defaults.removePersistentDomain(forName: "SyncPreferencesStoreTests")
    }

    func testChoicesSurviveARelaunchAndReachTheCloud() {
        let cloud = FakeCloudStore()
        let store = SyncPreferencesStore(defaults: defaults, cloud: cloud)
        store.setManualEntityId("lock.front_door", forAccessoryId: "lock")
        store.setAccessoryExcluded(true, accessoryId: "light")
        store.setRoomExcluded(true, homeId: "home", roomName: "Garage")

        let reloaded = SyncPreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.manualEntityId(forAccessoryId: "lock"), "lock.front_door")
        XCTAssertTrue(reloaded.isAccessoryExcluded("light"))
        XCTAssertTrue(reloaded.isRoomExcluded(homeId: "home", roomName: "garage"))
        XCTAssertEqual(reloaded.excludedRoomNames(homeId: "home"), ["garage"])
        XCTAssertEqual(reloaded.exclusionCount, 2)
        XCTAssertNotNil(cloud.storage[SyncPreferencesStore.defaultsKey])
    }

    func testAnotherDevicesChangeIsMergedIn() throws {
        let cloud = FakeCloudStore()
        let store = SyncPreferencesStore(defaults: defaults, cloud: cloud, now: { Date(timeIntervalSince1970: 1_000) })
        store.setAccessoryExcluded(true, accessoryId: "light")

        let remote = SyncPreferencesPayload(
            excludedAccessories: ["light": PreferenceEntry(value: nil, updatedAt: Date(timeIntervalSince1970: 2_000))]
        )
        cloud.storage[SyncPreferencesStore.defaultsKey] = try JSONEncoder().encode(remote)
        cloud.onExternalChange?()

        XCTAssertFalse(store.isAccessoryExcluded("light"))
    }

    func testAnExcludedRoomExcludesItsDevices() {
        let store = SyncPreferencesStore(defaults: defaults)
        store.setRoomExcluded(true, homeId: Fixtures.home.id, roomName: Fixtures.kitchenLight.roomName)

        XCTAssertTrue(store.isExcluded(Fixtures.kitchenLight, homeId: Fixtures.home.id))
        XCTAssertFalse(store.isExcluded(Fixtures.kitchenLight, homeId: "another-home"))
    }
}
