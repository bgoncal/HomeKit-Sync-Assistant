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
    /// The last server used to sync each Apple Home, so the Sync screen can offer
    /// the same pair again. It is a memory of a choice, not a binding link.
    var lastUsedServerByHome: [String: UUID] = [:]

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

        // A remembered pairing is a convenience, so the remote one only fills gaps.
        var pairings = remote.lastUsedServerByHome
        pairings.merge(local.lastUsedServerByHome) { _, mine in mine }
        pairings = pairings.filter { servers[$0.value] != nil }

        return ConfigurationPayload(
            servers: ordered,
            deletedServers: deletions
                .map { DeletedServer(id: $0.key, deletedAt: $0.value) }
                .sorted { $0.deletedAt < $1.deletedAt },
            lastUsedServerByHome: pairings
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
    @Published private(set) var lastUsedServerByHome: [String: UUID] = [:]
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

    /// The server to offer for an Apple Home: the one used last time, or the only
    /// one there is. Nothing is bound together — this is a pre-filled suggestion,
    /// and the choice is made again on every sync.
    func suggestedServer(forHomeId homeId: String) -> HomeAssistantServer? {
        if let remembered = lastUsedServerByHome[homeId], let server = server(id: remembered) {
            return server
        }
        return servers.count == 1 ? servers.first : nil
    }

    /// Records which pair was used, so the same one is offered next time.
    func rememberPairing(homeId: String, serverId: UUID) {
        guard lastUsedServerByHome[homeId] != serverId else { return }
        lastUsedServerByHome[homeId] = serverId
        save()
    }

    func state(forServerId id: UUID) -> ServerConnectionState {
        states[id] ?? .disconnected
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
        lastUsedServerByHome = lastUsedServerByHome.filter { $0.value != serverId }
        deletedServers.removeAll { $0.id == serverId }
        deletedServers.append(ConfigurationPayload.DeletedServer(id: serverId, deletedAt: Date()))
        tokens.removeToken(forServerId: serverId)
        save()
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
        lastUsedServerByHome = payload.lastUsedServerByHome.filter { pairing in
            servers.contains { $0.id == pairing.value }
        }
        for id in states.keys where !servers.contains(where: { $0.id == id }) {
            states[id] = nil
        }
    }

    private func currentPayload() -> ConfigurationPayload {
        ConfigurationPayload(
            servers: servers,
            deletedServers: deletedServers,
            lastUsedServerByHome: lastUsedServerByHome
        )
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
/// One server and how its connection is doing — what a screen needs to show a
/// connection as a single item.
struct ConnectionSummary: Identifiable, Equatable {
    let server: HomeAssistantServer
    let state: ServerConnectionState

    var id: UUID { server.id }
}

extension ConnectionStore {
    var summaries: [ConnectionSummary] {
        servers.map { ConnectionSummary(server: $0, state: state(forServerId: $0.id)) }
    }
}
