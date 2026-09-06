import Foundation

/// One Home Assistant instance the app can talk to.
///
/// The app supports several: a house and a holiday home each run their own server,
/// and each is paired with its own Apple Home. Everything needed to reach one lives
/// here, so connection settings can be shown and edited per server.
struct HomeAssistantServer: Identifiable, Codable, Equatable {
    let id: UUID
    /// What the person calls this server. Shown everywhere the server is named.
    var name: String
    /// The address typed in a browser, for example `http://homeassistant.local:8123`.
    var address: String
    var token: String
    /// Apple Home identifiers this server is paired with. A home belongs to exactly
    /// one server: its devices carry entity IDs from that one instance.
    var linkedHomeIds: [String]

    init(
        id: UUID = UUID(),
        name: String = "Home Assistant",
        address: String = "",
        token: String = "",
        linkedHomeIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.token = token
        self.linkedHomeIds = linkedHomeIds
    }

    /// The address with whitespace and a trailing slash removed.
    var normalizedAddress: String { HAConfiguration.normalizedURL(address) }

    /// Whether both fields look usable. It says nothing about whether the server answers.
    var isConfigured: Bool {
        HAConfiguration.urlProblem(address) == nil && HAConfiguration.tokenProblem(token) == nil
    }

    /// The first problem to fix, in the order a person fills the form in.
    var configurationProblem: String? {
        HAConfiguration.urlProblem(address) ?? HAConfiguration.tokenProblem(token)
    }
}

/// How a server's connection is doing right now.
enum ServerConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var isConnected: Bool { self == .connected }

    var title: String {
        switch self {
        case .disconnected: return "Not Connected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .failed: return "Connection Failed"
        }
    }

    var message: String? {
        guard case .failed(let message) = self else { return nil }
        return message
    }
}
