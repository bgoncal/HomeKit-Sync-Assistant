import XCTest
@testable import HomeKitBridge

/// Stand-ins for iCloud and the keychain, so the tests stay on this machine.
final class FakeCloudStore: ConfigurationSyncStore {
    var isAvailable = true
    var onExternalChange: (() -> Void)?
    private(set) var writes = 0
    var storage: [String: Data] = [:]

    func data(forKey key: String) -> Data? { storage[key] }

    func set(_ data: Data, forKey key: String) {
        storage[key] = data
        writes += 1
    }

    func startObserving() {}

    /// Pretend another device wrote this configuration.
    func receive(_ payload: ConfigurationPayload, forKey key: String = "homeAssistantConfiguration") {
        storage[key] = try? JSONEncoder().encode(payload)
        onExternalChange?()
    }
}

final class InMemoryTokenStore: TokenStore {
    private(set) var tokens: [UUID: String] = [:]

    func token(forServerId id: UUID) -> String? { tokens[id] }
    func setToken(_ token: String, forServerId id: UUID) {
        if token.isEmpty { tokens[id] = nil } else { tokens[id] = token }
    }
    func removeToken(forServerId id: UUID) { tokens[id] = nil }
}

final class ConfigurationPayloadTests: XCTestCase {
    private let id = UUID(uuidString: "AAAAAAAA-0000-0000-0000-0000000000FF")!

    func testTheNewerRecordWins() {
        let old = HomeAssistantServer(id: id, name: "House", updatedAt: Date(timeIntervalSince1970: 100))
        let new = HomeAssistantServer(id: id, name: "Beach House", updatedAt: Date(timeIntervalSince1970: 200))

        let merged = ConfigurationPayload.merged(
            ConfigurationPayload(servers: [old]),
            ConfigurationPayload(servers: [new])
        )

        XCTAssertEqual(merged.servers.map(\.name), ["Beach House"])
    }

    func testServersFromBothDevicesAreKept() {
        let here = HomeAssistantServer(name: "House", updatedAt: Date(timeIntervalSince1970: 100))
        let there = HomeAssistantServer(name: "Studio", updatedAt: Date(timeIntervalSince1970: 200))

        let merged = ConfigurationPayload.merged(
            ConfigurationPayload(servers: [here]),
            ConfigurationPayload(servers: [there])
        )

        XCTAssertEqual(Set(merged.servers.map(\.name)), ["House", "Studio"])
    }

    func testADeletionOnAnotherDeviceRemovesTheServer() {
        let server = HomeAssistantServer(id: id, name: "House", updatedAt: Date(timeIntervalSince1970: 100))
        let remote = ConfigurationPayload(
            servers: [],
            deletedServers: [.init(id: id, deletedAt: Date(timeIntervalSince1970: 150))]
        )

        let merged = ConfigurationPayload.merged(ConfigurationPayload(servers: [server]), remote)

        XCTAssertTrue(merged.servers.isEmpty)
        XCTAssertEqual(merged.deletedServers.map(\.id), [id])
    }

    /// Editing a server after it was deleted elsewhere brings it back — the person's
    /// most recent intent wins.
    func testAnEditAfterADeletionKeepsTheServer() {
        let edited = HomeAssistantServer(id: id, name: "House", updatedAt: Date(timeIntervalSince1970: 300))
        let remote = ConfigurationPayload(
            servers: [],
            deletedServers: [.init(id: id, deletedAt: Date(timeIntervalSince1970: 150))]
        )

        let merged = ConfigurationPayload.merged(ConfigurationPayload(servers: [edited]), remote)

        XCTAssertEqual(merged.servers.map(\.name), ["House"])
    }

    func testMergingIsOrderIndependent() {
        let a = HomeAssistantServer(name: "House", updatedAt: Date(timeIntervalSince1970: 100))
        let b = HomeAssistantServer(name: "Studio", updatedAt: Date(timeIntervalSince1970: 200))
        let left = ConfigurationPayload(servers: [a])
        let right = ConfigurationPayload(servers: [b])

        XCTAssertEqual(ConfigurationPayload.merged(left, right), ConfigurationPayload.merged(right, left))
    }

    func testTokensNeverTravelInThePayload() throws {
        let server = HomeAssistantServer(name: "House", address: "http://house.local:8123", token: "secret-token")
        let data = try JSONEncoder().encode(ConfigurationPayload(servers: [server]))
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(json.contains("secret-token"))
        XCTAssertTrue(json.contains("house.local"))
    }
}

@MainActor
final class ConnectionStoreCloudTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var cloud: FakeCloudStore!
    private var tokens: InMemoryTokenStore!

    override func setUp() {
        super.setUp()
        suiteName = "ConnectionStoreCloudTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        cloud = FakeCloudStore()
        tokens = InMemoryTokenStore()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore() -> ConnectionStore {
        ConnectionStore(defaults: defaults, cloud: cloud, tokens: tokens)
    }

    func testAddingAServerSharesItAndKeepsTheTokenOutOfTheSharedCopy() throws {
        let store = makeStore()
        let server = store.add(HomeAssistantServer(name: "House", address: "http://house.local:8123", token: "secret-token"))

        let shared = try XCTUnwrap(cloud.storage["homeAssistantConfiguration"])
        let payload = try JSONDecoder().decode(ConfigurationPayload.self, from: shared)

        XCTAssertEqual(payload.servers.map(\.name), ["House"])
        XCTAssertFalse(String(decoding: shared, as: UTF8.self).contains("secret-token"))
        XCTAssertEqual(tokens.token(forServerId: server.id), "secret-token")
    }

    func testAServerAddedOnAnotherDeviceAppearsHere() {
        let store = makeStore()
        let elsewhere = HomeAssistantServer(name: "Studio", address: "http://studio.local:8123", updatedAt: Date())

        cloud.receive(ConfigurationPayload(servers: [elsewhere]))

        XCTAssertEqual(store.servers.map(\.name), ["Studio"])
    }

    func testALocalEditSurvivesAnIncomingChange() {
        let store = makeStore()
        let here = store.add(HomeAssistantServer(name: "House", address: "http://house.local:8123"))
        let elsewhere = HomeAssistantServer(name: "Studio", address: "http://studio.local:8123", updatedAt: Date())

        cloud.receive(ConfigurationPayload(servers: [elsewhere]))

        XCTAssertEqual(Set(store.servers.map(\.name)), ["House", "Studio"])
        XCTAssertNotNil(store.server(id: here.id))
    }

    func testADeletionOnAnotherDeviceIsHonoured() {
        let store = makeStore()
        let server = store.add(HomeAssistantServer(name: "House", address: "http://house.local:8123"))

        cloud.receive(ConfigurationPayload(
            servers: [],
            deletedServers: [.init(id: server.id, deletedAt: Date().addingTimeInterval(60))]
        ))

        XCTAssertTrue(store.servers.isEmpty)
    }

    func testTheConfigurationIsRestoredFromICloudOnAFreshDevice() {
        let server = HomeAssistantServer(name: "House", address: "http://house.local:8123", linkedHomeIds: ["home-1"], updatedAt: Date())
        cloud.storage["homeAssistantConfiguration"] = try? JSONEncoder().encode(ConfigurationPayload(servers: [server]))
        tokens.setToken("secret-token", forServerId: server.id)

        let store = makeStore()

        XCTAssertEqual(store.servers.map(\.name), ["House"])
        XCTAssertEqual(store.server(forHomeId: "home-1")?.token, "secret-token")
    }

    func testDeletingAServerForgetsItsToken() {
        let store = makeStore()
        let server = store.add(HomeAssistantServer(name: "House", token: "secret-token"))

        store.remove(serverId: server.id)

        XCTAssertNil(tokens.token(forServerId: server.id))
    }
}

final class SyncDirectionTests: XCTestCase {
    func testEveryOperationCanBeTurnedAround() {
        for operation in SyncOperation.allCases {
            let inverted = operation.inverted
            XCTAssertEqual(inverted.subject, operation.subject)
            XCTAssertNotEqual(inverted.direction, operation.direction)
            XCTAssertEqual(inverted.inverted, operation, "Inverting twice should come back")
        }
    }

    func testASubjectAndADirectionPickOneOperation() {
        XCTAssertEqual(
            SyncDirection.homeAssistantToAppleHome.operation(for: .placement),
            .devicePlacementHAToHome
        )
        XCTAssertEqual(
            SyncDirection.appleHomeToHomeAssistant.operation(for: .names),
            .deviceNamesHomeToHA
        )
    }
}
