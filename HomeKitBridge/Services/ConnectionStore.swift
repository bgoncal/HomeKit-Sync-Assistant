import Foundation

/// Every Home Assistant server the app knows about, which Apple Home each one is
/// paired with, and the live connection for each.
///
/// A home belongs to exactly one server — its devices carry entity IDs from that
/// instance — while one server can serve several homes.
@MainActor
final class ConnectionStore: ObservableObject {
    @Published private(set) var servers: [HomeAssistantServer] = []
    @Published private(set) var states: [UUID: ServerConnectionState] = [:]

    private enum DefaultsKey {
        static let servers = "homeAssistantServers"
        static let didMigrateLegacyServer = "didMigrateLegacyHomeAssistantServer"
        static let legacyURL = "haURL"
        static let legacyToken = "haToken"
    }

    private let defaults: UserDefaults
    private var clients: [UUID: HAWebSocketClient] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
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

    /// Homes that have no server yet, so the UI can ask about them.
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
        servers.append(server)
        save()
        return server
    }

    func update(_ server: HomeAssistantServer) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }

        // A home can only belong to one server; moving it here takes it off the others.
        var updated = servers
        updated[index] = server
        for otherIndex in updated.indices where updated[otherIndex].id != server.id {
            updated[otherIndex].linkedHomeIds.removeAll { server.linkedHomeIds.contains($0) }
        }
        servers = updated

        clients[server.id]?.configure(address: server.normalizedAddress, token: server.token)
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
        save()
    }

    func link(homeId: String, toServerId serverId: UUID?) {
        var updated = servers
        for index in updated.indices {
            updated[index].linkedHomeIds.removeAll { $0 == homeId }
            if updated[index].id == serverId {
                updated[index].linkedHomeIds.append(homeId)
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

        guard let data = defaults.data(forKey: DefaultsKey.servers),
              let decoded = try? JSONDecoder().decode([HomeAssistantServer].self, from: data) else {
            servers = []
            return
        }
        servers = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        defaults.set(data, forKey: DefaultsKey.servers)
    }

    /// Earlier versions stored one address and token at the top level. Fold that into
    /// the first server so an upgrade keeps working without asking anything.
    private func migrateLegacyServerIfNeeded() {
        guard !defaults.bool(forKey: DefaultsKey.didMigrateLegacyServer) else { return }
        defaults.set(true, forKey: DefaultsKey.didMigrateLegacyServer)

        guard defaults.data(forKey: DefaultsKey.servers) == nil else { return }

        let address = defaults.string(forKey: DefaultsKey.legacyURL) ?? ""
        let token = defaults.string(forKey: DefaultsKey.legacyToken) ?? ""
        guard !HAConfiguration.normalizedURL(address).isEmpty || !token.isEmpty else { return }

        let server = HomeAssistantServer(name: "Home Assistant", address: address, token: token)
        if let data = try? JSONEncoder().encode([server]) {
            defaults.set(data, forKey: DefaultsKey.servers)
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
