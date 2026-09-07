import XCTest
@testable import HomeKitBridge

@MainActor
final class ConnectionStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var tokens: InMemoryTokenStore!

    override func setUp() {
        super.setUp()
        suiteName = "ConnectionStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        tokens = InMemoryTokenStore()
    }

    private func makeStore() -> ConnectionStore {
        ConnectionStore(defaults: defaults, tokens: tokens)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testAddedServersSurviveAReload() {
        let store = makeStore()
        store.add(HomeAssistantServer(name: "House", address: "http://house.local:8123", token: String(repeating: "a", count: 40)))

        let reloaded = ConnectionStore(defaults: defaults, tokens: tokens)
        XCTAssertEqual(reloaded.servers.map(\.name), ["House"])
    }

    func testASecondServerGetsItsOwnDefaultName() {
        let store = makeStore()
        store.add(HomeAssistantServer(name: ""))
        store.add(HomeAssistantServer(name: ""))

        XCTAssertEqual(store.servers.map(\.name), ["Home Assistant", "Home Assistant 2"])
    }

    func testTheServerUsedLastTimeIsOfferedAgain() {
        let store = makeStore()
        store.add(HomeAssistantServer(name: "House"))
        let beach = store.add(HomeAssistantServer(name: "Beach"))

        store.rememberPairing(homeId: "home-1", serverId: beach.id)

        XCTAssertEqual(store.suggestedServer(forHomeId: "home-1")?.id, beach.id)
    }

    func testWithOneServerItIsOfferedWithoutAnyHistory() {
        let store = makeStore()
        store.add(HomeAssistantServer(name: "House"))

        XCTAssertEqual(store.suggestedServer(forHomeId: "any-home")?.name, "House")
    }

    func testWithTwoServersAndNoHistoryNothingIsAssumed() {
        let store = makeStore()
        store.add(HomeAssistantServer(name: "House"))
        store.add(HomeAssistantServer(name: "Beach"))

        XCTAssertNil(store.suggestedServer(forHomeId: "home-3"))
    }

    func testARememberedPairingSurvivesAReload() {
        let store = makeStore()
        let house = store.add(HomeAssistantServer(name: "House"))
        store.add(HomeAssistantServer(name: "Beach"))
        store.rememberPairing(homeId: "home-1", serverId: house.id)

        let reloaded = ConnectionStore(defaults: defaults, tokens: tokens)

        XCTAssertEqual(reloaded.suggestedServer(forHomeId: "home-1")?.id, house.id)
    }

    func testRemovingAServerForgetsPairingsThatUsedIt() {
        let store = makeStore()
        let house = store.add(HomeAssistantServer(name: "House"))
        store.add(HomeAssistantServer(name: "Beach"))
        store.add(HomeAssistantServer(name: "Studio"))
        store.rememberPairing(homeId: "home-1", serverId: house.id)

        store.remove(serverId: house.id)

        // Two servers are left, so nothing can be assumed: the memory is gone.
        XCTAssertNil(store.suggestedServer(forHomeId: "home-1"))
    }

    func testTheOldSingleServerSettingsAreMigrated() {
        defaults.set("http://homeassistant.local:8123", forKey: "haURL")
        defaults.set(String(repeating: "a", count: 40), forKey: "haToken")

        let store = makeStore()

        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(store.servers.first?.address, "http://homeassistant.local:8123")
        XCTAssertEqual(store.servers.first?.name, "Home Assistant")
        // And it serves the existing home without anyone linking anything.
        XCTAssertNotNil(store.suggestedServer(forHomeId: "home-1"))
    }

    func testMigrationDoesNotRunTwice() {
        defaults.set("http://homeassistant.local:8123", forKey: "haURL")
        defaults.set(String(repeating: "a", count: 40), forKey: "haToken")

        let store = makeStore()
        store.remove(serverId: store.servers[0].id)

        let reloaded = ConnectionStore(defaults: defaults, tokens: tokens)
        XCTAssertTrue(reloaded.servers.isEmpty)
    }

    func testNothingIsMigratedWhenThereWasNoOldServer() {
        XCTAssertTrue(ConnectionStore(defaults: defaults, tokens: tokens).servers.isEmpty)
    }

    func testRemovingAServerLeavesTheOthers() {
        let store = makeStore()
        let house = store.add(HomeAssistantServer(name: "House"))
        store.add(HomeAssistantServer(name: "Beach"))

        store.remove(serverId: house.id)

        XCTAssertEqual(store.servers.map(\.name), ["Beach"])
    }

    func testSummariesCarryEachServersState() {
        let store = makeStore()
        store.add(HomeAssistantServer(name: "House"))
        store.add(HomeAssistantServer(name: "Beach"))

        XCTAssertEqual(store.summaries.map(\.server.name), ["House", "Beach"])
        XCTAssertEqual(store.summaries.map(\.state), [.disconnected, .disconnected])
    }
}
