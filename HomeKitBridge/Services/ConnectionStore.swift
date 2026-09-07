import Foundation

/// The configuration as it is shared between devices: the servers, and the ones
/// that were deleted so a deletion is not undone by an older device coming back.
struct ConfigurationPayload: Codable, Equatable {
    struct DeletedServer: Codable, Equatable {
        let id: UUID
        let deletedAt: Date
    }

    var servers: [HomeAssistantServer] = []
    var deletedServers: [DeletedServer] = []

    /// Combines two copies of the configuration without a server, by taking the
    /// newer record for each id and honouring deletions that happened after it.
    static func merged(_ local: ConfigurationPayload, _ remote: ConfigurationPayload) -> ConfigurationPayload {
        var servers: [UUID: HomeAssistantServer] = [:]
        for server in local.servers + remote.servers {
            if let existing = servers[server.id], existing.updatedAt >= server.updatedAt { continue }
            servers[server.id] = server
        }

        var deletions: [UUID: Date] = [:]
        for deletion in local.deletedServers + remote.deletedServers {
            if let existing = deletions[deletion.id], existing >= deletion.deletedAt { continue }
            deletions[deletion.id] = deletion.deletedAt
        }

        for (id, deletedAt) in deletions {
            if let server = servers[id], server.updatedAt > deletedAt { continue }
            servers[id] = nil
        }

        // Keep the order stable across devices: oldest record first.
        let ordered = servers.values.sorted { ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString) }
        return ConfigurationPayload(
            servers: ordered,
            deletedServers: deletions
                .map { DeletedServer(id: $0.key, deletedAt: $0.value) }
                .sorted { $0.deletedAt < $1.deletedAt }
        )
    }
}

/// Every Home Assistant server the app knows about, which Apple Home each one is
/// paired with, and the live connection for each.
///
/// A home belongs to exactly one server — its devices carry entity IDs from that
/// instance — while one server can serve several homes.
///
/// The configuration is shared across the person's devices: the records travel
/// through iCloud's key-value store, and the tokens through the iCloud keychain.
@MainActor
final class ConnectionStore: ObservableObject {
    @Published private(set) var servers: [HomeAssistantServer] = []
    @Published private(set) var states: [UUID: ServerConnectionState] = [:]
    /// False when iCloud is unavailable (signed out, or turned off), so the UI can
    /// say the configuration is only on this device.
    @Published private(set) var isSyncingWithCloud = false

    private enum DefaultsKey {
        static let configuration = "homeAssistantConfiguration"
        static let legacyServers = "homeAssistantServers"
        static let didMigrateLegacyServer = "didMigrateLegacyHomeAssistantServer"
        static let legacyURL = "haURL"
        static let legacyToken = "haToken"
    }

    private let defaults: UserDefaults
    private let cloud: ConfigurationSyncStore?
    private let tokens: TokenStore
    private var deletedServers: [ConfigurationPayload.DeletedServer] = []
    private var clients: [UUID: HAWebSocketClient] = [:]

    init(defaults: UserDefaults = .standard, cloud: ConfigurationSyncStore? = nil, tokens: TokenStore) {
        self.defaults = defaults
        self.cloud = cloud
        self.tokens = tokens
        load()

        cloud?.onExternalChange = { [weak self] in
            self?.mergeFromCloud()
        }
        cloud?.startObserving()
        isSyncingWithCloud = cloud?.isAvailable ?? false
    }

    // MARK: - Lookup

    func server(id: UUID) -> HomeAssistantServer? {
        servers.first { $0.id == id }
    }

    /// The server paired with an Apple Home.
    ///
    /// A single server with no explicit link still serves every home: that is what
    /// setups upgraded from the one-server version look like until someone links them.
    func server(forHomeId homeId: String) -> HomeAssistantServer? {
        if let linked = servers.first(where: { $0.linkedHomeIds.contains(homeId) }) {
            return linked
        }
        if servers.count == 1, servers[0].linkedHomeIds.isEmpty {
            return servers[0]
        }
        return nil
    }

    func state(forServerId id: UUID) -> ServerConnectionState {
        states[id] ?? .disconnected
    }

    func state(forHomeId homeId: String) -> ServerConnectionState? {
        server(forHomeId: homeId).map { state(forServerId: $0.id) }
    }

    func unlinkedHomeIds(among homeIds: [String]) -> [String] {
        homeIds.filter { server(forHomeId: $0) == nil }
    }

    // MARK: - Editing

    @discardableResult
    func add(_ server: HomeAssistantServer) -> HomeAssistantServer {
        var server = server
        if server.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            server.name = defaultName()
        }
        server.updatedAt = Date()
        servers.append(server)
        save()
        return server
    }

    func update(_ server: HomeAssistantServer) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        guard !server.hasSameContent(as: servers[index]) else { return }

        var updated = servers
        var stamped = server
        stamped.updatedAt = Date()
        updated[index] = stamped

        // A home can only belong to one server; moving it here takes it off the others.
        for otherIndex in updated.indices where updated[otherIndex].id != server.id {
            let overlap = updated[otherIndex].linkedHomeIds.filter { server.linkedHomeIds.contains($0) }
            guard !overlap.isEmpty else { continue }
            updated[otherIndex].linkedHomeIds.removeAll { server.linkedHomeIds.contains($0) }
            updated[otherIndex].updatedAt = Date()
        }
        servers = updated

        clients[server.id]?.configure(address: stamped.normalizedAddress, token: stamped.token)
        if states[server.id]?.isConnected == false {
            states[server.id] = .disconnected
        }
        save()
    }

    func remove(serverId: UUID) {
        clients[serverId]?.disconnect()
        clients[serverId] = nil
        states[serverId] = nil
        servers.removeAll { $0.id == serverId }
        deletedServers.removeAll { $0.id == serverId }
        deletedServers.append(ConfigurationPayload.DeletedServer(id: serverId, deletedAt: Date()))
        tokens.removeToken(forServerId: serverId)
        save()
    }

    func link(homeId: String, toServerId serverId: UUID?) {
        var updated = servers
        for index in updated.indices {
            let had = updated[index].linkedHomeIds.contains(homeId)
            updated[index].linkedHomeIds.removeAll { $0 == homeId }
            if updated[index].id == serverId {
                updated[index].linkedHomeIds.append(homeId)
            }
            if had != updated[index].linkedHomeIds.contains(homeId) {
                updated[index].updatedAt = Date()
            }
        }
        servers = updated
        save()
    }

    /// Used when setup finishes: a first server serves everything found so far.
    func linkAllHomes(_ homeIds: [String], toServerId serverId: UUID) {
        for homeId in homeIds where server(forHomeId: homeId) == nil {
            link(homeId: homeId, toServerId: serverId)
        }
    }

    private func defaultName() -> String {
        let base = "Home Assistant"
        guard servers.contains(where: { $0.name == base }) else { return base }
        var index = 2
        while servers.contains(where: { $0.name == "\(base) \(index)" }) {
            index += 1
        }
        return "\(base) \(index)"
    }

    // MARK: - Connections

    func client(forServerId serverId: UUID) -> HAWebSocketClient? {
        guard let server = server(id: serverId) else { return nil }

        if let client = clients[serverId] {
            client.configure(address: server.normalizedAddress, token: server.token)
            return client
        }

        let client = HAWebSocketClient(address: server.normalizedAddress, token: server.token)
        client.onStateChange = { [weak self] isConnected, error in
            guard let self else { return }
            if isConnected {
                self.states[serverId] = .connected
            } else if let error, !error.isEmpty {
                self.states[serverId] = .failed(error)
            } else {
                self.states[serverId] = .disconnected
            }
        }
        clients[serverId] = client
        return client
    }

    func client(forHomeId homeId: String) -> HAWebSocketClient? {
        server(forHomeId: homeId).flatMap { client(forServerId: $0.id) }
    }

    @discardableResult
    func connect(serverId: UUID) async -> Bool {
        guard let client = client(forServerId: serverId) else { return false }
        states[serverId] = .connecting
        return await client.connect()
    }

    func disconnect(serverId: UUID) {
        clients[serverId]?.disconnect()
        states[serverId] = .disconnected
    }

    /// Opens every configured server at launch, so the Dashboard is truthful.
    func connectAll() async {
        for server in servers where server.isConfigured {
            _ = await connect(serverId: server.id)
        }
    }

    // MARK: - Persistence

    private func load() {
        migrateLegacyServerIfNeeded()

        var payload = localPayload()
        if let cloudPayload = cloudPayload() {
            payload = ConfigurationPayload.merged(payload, cloudPayload)
        }

        apply(payload)
        // Whatever the merge produced is now the shared truth.
        write(payload)
    }

    /// Another device changed something. Merge it in rather than overwriting, so an
    /// edit made here while offline is not lost.
    private func mergeFromCloud() {
        guard let cloudPayload = cloudPayload() else { return }
        let merged = ConfigurationPayload.merged(currentPayload(), cloudPayload)
        guard merged != currentPayload() else { return }

        apply(merged)
        write(merged)

        for server in servers {
            clients[server.id]?.configure(address: server.normalizedAddress, token: server.token)
        }
    }

    private func apply(_ payload: ConfigurationPayload) {
        // Tokens never travel in the payload; they come from the keychain.
        servers = payload.servers.map { server in
            var server = server
            server.token = tokens.token(forServerId: server.id) ?? server.token
            return server
        }
        deletedServers = payload.deletedServers
        for id in states.keys where !servers.contains(where: { $0.id == id }) {
            states[id] = nil
        }
    }

    private func currentPayload() -> ConfigurationPayload {
        ConfigurationPayload(servers: servers, deletedServers: deletedServers)
    }

    private func save() {
        let payload = currentPayload()
        for server in servers {
            tokens.setToken(server.token, forServerId: server.id)
        }
        write(payload)
        isSyncingWithCloud = cloud?.isAvailable ?? false
    }

    private func write(_ payload: ConfigurationPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: DefaultsKey.configuration)
        cloud?.set(data, forKey: DefaultsKey.configuration)
    }

    private func localPayload() -> ConfigurationPayload {
        guard let data = defaults.data(forKey: DefaultsKey.configuration) else {
            return legacyLocalPayload()
        }
        return (try? JSONDecoder().decode(ConfigurationPayload.self, from: data)) ?? legacyLocalPayload()
    }

    /// The shape written before the configuration was shared: a bare list of servers.
    private func legacyLocalPayload() -> ConfigurationPayload {
        guard let data = defaults.data(forKey: DefaultsKey.legacyServers),
              let servers = try? JSONDecoder().decode([HomeAssistantServer].self, from: data) else {
            return ConfigurationPayload()
        }
        return ConfigurationPayload(servers: servers.map { server in
            var server = server
            if server.updatedAt == .distantPast {
                server.updatedAt = Date()
            }
            return server
        })
    }

    private func cloudPayload() -> ConfigurationPayload? {
        guard let data = cloud?.data(forKey: DefaultsKey.configuration) else { return nil }
        return try? JSONDecoder().decode(ConfigurationPayload.self, from: data)
    }

    /// Earlier versions stored one address and token at the top level. Fold that into
    /// the first server so an upgrade keeps working without asking anything.
    private func migrateLegacyServerIfNeeded() {
        guard !defaults.bool(forKey: DefaultsKey.didMigrateLegacyServer) else { return }
        defaults.set(true, forKey: DefaultsKey.didMigrateLegacyServer)

        guard defaults.data(forKey: DefaultsKey.configuration) == nil,
              defaults.data(forKey: DefaultsKey.legacyServers) == nil else { return }

        let address = defaults.string(forKey: DefaultsKey.legacyURL) ?? ""
        let token = defaults.string(forKey: DefaultsKey.legacyToken) ?? ""
        guard !HAConfiguration.normalizedURL(address).isEmpty || !token.isEmpty else { return }

        let server = HomeAssistantServer(name: "Home Assistant", address: address, token: token)
        tokens.setToken(token, forServerId: server.id)
        if let data = try? JSONEncoder().encode(ConfigurationPayload(servers: [server])) {
            defaults.set(data, forKey: DefaultsKey.configuration)
        }
    }
}
/// One server, how its connection is doing, and the Apple Homes it serves —
/// everything a screen needs to show a connection as a single grouped item.
struct ConnectionSummary: Identifiable, Equatable {
    let server: HomeAssistantServer
    let state: ServerConnectionState
    let linkedHomes: [HomeSummary]

    var id: UUID { server.id }
}

extension ConnectionStore {
    /// The servers, each with its state and the homes it serves.
    func summaries(homes: [HomeSummary]) -> [ConnectionSummary] {
        servers.map { server in
            let linked = homes.filter { home in
                self.server(forHomeId: home.id)?.id == server.id
            }
            return ConnectionSummary(server: server, state: state(forServerId: server.id), linkedHomes: linked)
        }
    }

    /// Homes with no server, which is what the UI nudges people to fix.
    func unlinkedHomes(_ homes: [HomeSummary]) -> [HomeSummary] {
        homes.filter { server(forHomeId: $0.id) == nil }
    }
}
