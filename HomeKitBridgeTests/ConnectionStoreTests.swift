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

    // MARK: - Duplicates

    private let token = String(repeating: "t", count: 40)

    /// Saving the same record again, as the old editor did on every keystroke, keeps one.
    func testAddingTheSameServerTwiceKeepsOne() {
        let store = makeStore()
        var server = HomeAssistantServer(name: "House", address: "http://house.local:8123", token: token)
        store.add(server)
        server.address = "http://house.local:8124"
        store.add(server)

        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(store.servers.first?.address, "http://house.local:8124")
    }

    /// Retrying an add after an error makes a new draft; the same address must not make a copy.
    func testAddingTheSameAddressAgainUpdatesTheFirst() {
        let store = makeStore()
        let first = store.add(HomeAssistantServer(name: "House", address: "http://House.local:8123/", token: token))
        let second = store.add(HomeAssistantServer(name: "Home Assistant", address: "house.local:8123", token: String(repeating: "u", count: 40)))

        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(store.servers.first?.token, String(repeating: "u", count: 40))
        XCTAssertEqual(store.server(matchingAddress: "HTTP://house.local:8123")?.id, first.id)
        XCTAssertNil(store.server(matchingAddress: "house.local:8123", excluding: first.id))
    }

    private func storeHolding(_ servers: [HomeAssistantServer], tokens values: [UUID: String], lastUsed: [String: UUID] = [:]) throws -> ConnectionStore {
        let payload = ConfigurationPayload(servers: servers, lastUsedServerByHome: lastUsed)
        defaults.set(try JSONEncoder().encode(payload), forKey: "homeAssistantConfiguration")
        for (id, token) in values { tokens.setToken(token, forServerId: id) }
        return makeStore()
    }

    private func server(_ id: String, _ name: String, _ address: String, at time: TimeInterval) -> HomeAssistantServer {
        HomeAssistantServer(id: UUID(uuidString: id)!, name: name, address: address, updatedAt: Date(timeIntervalSince1970: time))
    }

    /// Copies left by earlier versions — the same id appended, or the same address and
    /// token — fold on launch into the copy with the lowest id, the same on every device.
    func testDuplicatesFromEarlierVersionsFoldIntoTheLowestId() throws {
        let low = server("00000000-0000-0000-0000-000000000001", "Home Assistant", "house.local:8123", at: 2_000)
        let high = server("FFFFFFFF-0000-0000-0000-000000000001", "House", "http://house.local:8123", at: 1_000)
        let beach = server("AAAAAAAA-0000-0000-0000-000000000001", "Beach", "http://beach.local:8123", at: 3_000)

        let store = try storeHolding(
            [high, high, low, beach],
            tokens: [low.id: token, high.id: token, beach.id: token],
            lastUsed: ["home": high.id]
        )

        XCTAssertEqual(Set(store.servers.map(\.id)), [low.id, beach.id])
        // The remembered pairing moves to the copy that was kept, and its token stays put.
        XCTAssertEqual(store.lastUsedServerByHome["home"], low.id)
        XCTAssertEqual(tokens.token(forServerId: high.id), token)
        XCTAssertEqual(store.takeFoldedServers(), [high.id: low.id])
        XCTAssertTrue(store.takeFoldedServers().isEmpty)
    }

    /// A copy whose token has not reached this device is never taken for a duplicate.
    func testACopyWithoutATokenIsNotFolded() throws {
        let one = server("00000000-0000-0000-0000-000000000001", "House", "http://house.local:8123", at: 1)
        let two = server("00000000-0000-0000-0000-000000000002", "House", "http://house.local:8123", at: 2)
        let store = try storeHolding([one, two], tokens: [one.id: token])
        XCTAssertEqual(store.servers.count, 2)
    }

    /// http:// and https:// copies stay apart: one of them may be the one that works.
    func testHttpAndHttpsCopiesAreNotFolded() throws {
        let plain = server("00000000-0000-0000-0000-000000000001", "House", "http://house.example.com", at: 1)
        let secure = server("00000000-0000-0000-0000-000000000002", "House", "https://house.example.com", at: 2)
        let store = try storeHolding([plain, secure], tokens: [plain.id: token, secure.id: token])
        XCTAssertEqual(store.servers.count, 2)
    }

    /// Two devices that remember different copies still keep the same one.
    func testEveryDeviceKeepsTheSameCopy() throws {
        let low = server("00000000-0000-0000-0000-000000000001", "House", "http://house.local:8123", at: 1)
        let high = server("FFFFFFFF-0000-0000-0000-000000000001", "House", "http://house.local:8123", at: 2)
        let first = try storeHolding([low, high], tokens: [low.id: token, high.id: token], lastUsed: ["home": high.id])
        defaults.removePersistentDomain(forName: suiteName)
        let second = try storeHolding([high, low], tokens: [low.id: token, high.id: token], lastUsed: ["home": low.id])
        XCTAssertEqual(first.servers.map(\.id), [low.id])
        XCTAssertEqual(second.servers.map(\.id), [low.id])
    }

    /// Retyping an address with https:// keeps what was typed.
    func testAddingTheSameAddressTakesTheTypedAddress() {
        let store = makeStore()
        store.add(HomeAssistantServer(name: "House", address: "http://house.local:8123", token: token))
        store.add(HomeAssistantServer(name: "House", address: "https://house.local:8123", token: token))
        XCTAssertEqual(store.servers.map(\.address), ["https://house.local:8123"])
    }

    func testUniqueByIdKeepsTheNewestCopy() {
        let id = UUID()
        let old = HomeAssistantServer(id: id, name: "Old", updatedAt: Date(timeIntervalSince1970: 1))
        let new = HomeAssistantServer(id: id, name: "New", updatedAt: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(ConnectionStore.uniqueById([old, new]).map(\.name), ["New"])
    }
}

final class ConnectionProblemTests: XCTestCase {
    private let url = URL(string: "ws://homeassistant.local:8123/api/websocket")!

    func testNetworkErrorsBecomeSomethingToCheck() {
        XCTAssertEqual(ConnectionProblem.describe(URLError(.cannotFindHost), statusCode: nil, url: url).title, "Address Not Found")
        XCTAssertEqual(ConnectionProblem.describe(URLError(.cannotConnectToHost), statusCode: nil, url: url).title, "Connection Refused")
        XCTAssertEqual(ConnectionProblem.describe(URLError(.timedOut), statusCode: nil, url: url).title, "No Answer")
        XCTAssertEqual(ConnectionProblem.describe(URLError(.serverCertificateUntrusted), statusCode: nil, url: url).title, "Certificate Not Trusted")
        XCTAssertEqual(ConnectionProblem.describe(URLError(.appTransportSecurityRequiresSecureConnection), statusCode: nil, url: url).title, "Secure Address Needed")
        XCTAssertTrue(ConnectionProblem.describe(URLError(.cannotConnectToHost), statusCode: nil, url: url).message.contains("port 8123"))
    }

    /// The handshake's HTTP status says more than the socket error that follows it.
    func testHTTPStatusWins() {
        XCTAssertEqual(ConnectionProblem.describe(URLError(.badServerResponse), statusCode: 404, url: url).title, "Not Home Assistant")
        XCTAssertEqual(ConnectionProblem.describe(URLError(.badServerResponse), statusCode: 403, url: url).title, "Access Refused")
    }

    /// A home address that times out points at the Local Network permission; a remote one does not.
    func testLocalHostsMentionLocalNetworkAccess() {
        XCTAssertTrue(ConnectionProblem.describe(URLError(.timedOut), statusCode: nil, url: url).message.contains("Local Network"))
        let remote = URL(string: "wss://example.ui.nabu.casa/api/websocket")!
        XCTAssertFalse(ConnectionProblem.describe(URLError(.timedOut), statusCode: nil, url: remote).message.contains("Local Network"))
    }

    func testWhichHostsAreLocal() {
        XCTAssertTrue(ConnectionProblem.isLocal("homeassistant.local"))
        XCTAssertTrue(ConnectionProblem.isLocal("192.168.1.20"))
        XCTAssertTrue(ConnectionProblem.isLocal("172.20.0.5"))
        XCTAssertTrue(ConnectionProblem.isLocal("homeassistant"))
        XCTAssertFalse(ConnectionProblem.isLocal("172.40.0.5"))
        XCTAssertFalse(ConnectionProblem.isLocal("example.ui.nabu.casa"))
    }

    /// Home Assistant's own words are quoted, so they can be searched.
    func testTheRejectionQuotesHomeAssistant() {
        XCTAssertTrue(ConnectionProblem.tokenRejected(reason: "Invalid access token").message.contains("“Invalid access token”"))
    }
}
