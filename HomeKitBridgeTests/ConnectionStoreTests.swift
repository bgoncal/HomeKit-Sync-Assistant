import XCTest
@testable import HomeKitBridge

@MainActor
final class ConnectionStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ConnectionStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testAddedServersSurviveAReload() {
        let store = ConnectionStore(defaults: defaults)
        store.add(HomeAssistantServer(name: "House", address: "http://house.local:8123", token: String(repeating: "a", count: 40)))

        let reloaded = ConnectionStore(defaults: defaults)
        XCTAssertEqual(reloaded.servers.map(\.name), ["House"])
    }

    func testASecondServerGetsItsOwnDefaultName() {
        let store = ConnectionStore(defaults: defaults)
        store.add(HomeAssistantServer(name: ""))
        store.add(HomeAssistantServer(name: ""))

        XCTAssertEqual(store.servers.map(\.name), ["Home Assistant", "Home Assistant 2"])
    }

    func testAHomeBelongsToOnlyOneServer() {
        let store = ConnectionStore(defaults: defaults)
        let house = store.add(HomeAssistantServer(name: "House", linkedHomeIds: ["home-1"]))
        let beach = store.add(HomeAssistantServer(name: "Beach"))

        store.link(homeId: "home-1", toServerId: beach.id)

        XCTAssertEqual(store.server(forHomeId: "home-1")?.id, beach.id)
        XCTAssertEqual(store.server(id: house.id)?.linkedHomeIds, [])
    }

    func testLinkingThroughUpdateAlsoTakesTheHomeOffTheOtherServer() {
        let store = ConnectionStore(defaults: defaults)
        let house = store.add(HomeAssistantServer(name: "House", linkedHomeIds: ["home-1"]))
        var beach = store.add(HomeAssistantServer(name: "Beach"))

        beach.linkedHomeIds = ["home-1"]
        store.update(beach)

        XCTAssertEqual(store.server(id: house.id)?.linkedHomeIds, [])
        XCTAssertEqual(store.server(forHomeId: "home-1")?.id, beach.id)
    }

    func testUnlinkingLeavesTheHomeWithoutAServer() {
        let store = ConnectionStore(defaults: defaults)
        let house = store.add(HomeAssistantServer(name: "House", linkedHomeIds: ["home-1"]))
        store.add(HomeAssistantServer(name: "Beach"))

        store.link(homeId: "home-1", toServerId: nil)

        XCTAssertNil(store.server(forHomeId: "home-1"))
        XCTAssertEqual(store.server(id: house.id)?.linkedHomeIds, [])
    }

    /// An upgrade from the one-server version has no links yet, and everything
    /// should keep working until someone sets them.
    func testASingleUnlinkedServerStillServesEveryHome() {
        let store = ConnectionStore(defaults: defaults)
        store.add(HomeAssistantServer(name: "House"))

        XCTAssertEqual(store.server(forHomeId: "any-home")?.name, "House")
    }

    func testWithTwoServersAnUnlinkedHomeHasNone() {
        let store = ConnectionStore(defaults: defaults)
        store.add(HomeAssistantServer(name: "House", linkedHomeIds: ["home-1"]))
        store.add(HomeAssistantServer(name: "Beach", linkedHomeIds: ["home-2"]))

        XCTAssertNil(store.server(forHomeId: "home-3"))
    }

    func testTheOldSingleServerSettingsAreMigrated() {
        defaults.set("http://homeassistant.local:8123", forKey: "haURL")
        defaults.set(String(repeating: "a", count: 40), forKey: "haToken")

        let store = ConnectionStore(defaults: defaults)

        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(store.servers.first?.address, "http://homeassistant.local:8123")
        XCTAssertEqual(store.servers.first?.name, "Home Assistant")
        // And it serves the existing home without anyone linking anything.
        XCTAssertNotNil(store.server(forHomeId: "home-1"))
    }

    func testMigrationDoesNotRunTwice() {
        defaults.set("http://homeassistant.local:8123", forKey: "haURL")
        defaults.set(String(repeating: "a", count: 40), forKey: "haToken")

        let store = ConnectionStore(defaults: defaults)
        store.remove(serverId: store.servers[0].id)

        let reloaded = ConnectionStore(defaults: defaults)
        XCTAssertTrue(reloaded.servers.isEmpty)
    }

    func testNothingIsMigratedWhenThereWasNoOldServer() {
        XCTAssertTrue(ConnectionStore(defaults: defaults).servers.isEmpty)
    }

    func testRemovingAServerDropsItsLinks() {
        let store = ConnectionStore(defaults: defaults)
        let house = store.add(HomeAssistantServer(name: "House", linkedHomeIds: ["home-1"]))
        store.add(HomeAssistantServer(name: "Beach", linkedHomeIds: ["home-2"]))

        store.remove(serverId: house.id)

        XCTAssertNil(store.server(forHomeId: "home-1"))
        XCTAssertEqual(store.servers.map(\.name), ["Beach"])
    }

    func testSummariesGroupHomesUnderTheirServer() {
        let store = ConnectionStore(defaults: defaults)
        store.add(HomeAssistantServer(name: "House", linkedHomeIds: [Fixtures.home.id]))
        store.add(HomeAssistantServer(name: "Beach", linkedHomeIds: [Fixtures.secondHome.id]))

        let summaries = store.summaries(homes: [Fixtures.home, Fixtures.secondHome])

        XCTAssertEqual(summaries.map(\.server.name), ["House", "Beach"])
        XCTAssertEqual(summaries[0].linkedHomes.map(\.name), [Fixtures.home.name])
        XCTAssertEqual(summaries[1].linkedHomes.map(\.name), [Fixtures.secondHome.name])
        XCTAssertTrue(store.unlinkedHomes([Fixtures.home, Fixtures.secondHome]).isEmpty)
    }

    func testLinkAllHomesLeavesExistingPairingsAlone() {
        let store = ConnectionStore(defaults: defaults)
        let house = store.add(HomeAssistantServer(name: "House", linkedHomeIds: ["home-1"]))
        let beach = store.add(HomeAssistantServer(name: "Beach"))

        store.linkAllHomes(["home-1", "home-2"], toServerId: beach.id)

        XCTAssertEqual(store.server(forHomeId: "home-1")?.id, house.id)
        XCTAssertEqual(store.server(forHomeId: "home-2")?.id, beach.id)
    }
}

@MainActor
final class ScheduledSyncAvailabilityTests: XCTestCase {
    /// Scheduled syncs are a Mac feature: iPhone and iPad suspend the app, so a
    /// daily timer there would be a promise the platform does not keep.
    func testScheduledSyncsAreMacOnly() {
        #if targetEnvironment(macCatalyst) || os(macOS)
        XCTAssertTrue(ScheduledActionManager.isSupported)
        #else
        XCTAssertFalse(ScheduledActionManager.isSupported)
        #endif
    }
}

final class ScheduledActionCodingTests: XCTestCase {
    /// Schedules saved before homes existed decode with an empty home, which means
    /// "the home selected in the app".
    func testASavedScheduleWithoutAHomeStillDecodes() throws {
        let json = """
        {
          "id": "EEEEEEEE-0000-0000-0000-000000000009",
          "isEnabled": true,
          "timeMinutes": 480,
          "operationRawValue": "placement.homeAssistantToAppleHome"
        }
        """
        let schedule = try JSONDecoder().decode(ScheduledAction.self, from: Data(json.utf8))

        XCTAssertEqual(schedule.homeId, "")
        XCTAssertEqual(schedule.operation, .devicePlacementHAToHome)
    }
}
