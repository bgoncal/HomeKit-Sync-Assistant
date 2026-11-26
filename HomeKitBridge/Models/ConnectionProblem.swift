import Foundation

/// Why a connection to Home Assistant failed, in words a person can act on: a short
/// title for the status row and one or two sentences saying what to check next.
///
/// Built from what actually went wrong — the network error, the HTTP status of the
/// WebSocket handshake, or Home Assistant's own answer — so "could not connect" is the
/// last resort, not the only message there is.
struct ConnectionProblem: Error, LocalizedError, Equatable {
    let title: String
    let message: String

    var errorDescription: String? { message }

    // MARK: - Before connecting

    static let noAddress = ConnectionProblem(
        title: "No Address",
        message: "Enter the address you open Home Assistant with, for example http://homeassistant.local:8123."
    )

    static let noToken = ConnectionProblem(
        title: "No Access Token",
        message: "Paste a long-lived access token. In Home Assistant: your profile → Security → Long-lived access tokens."
    )

    static func invalidAddress(_ address: String) -> ConnectionProblem {
        ConnectionProblem(
            title: "Address Not Valid",
            message: "“\(address)” is not an address the app can open. Try http://homeassistant.local:8123."
        )
    }

    // MARK: - Home Assistant's own answers

    static func notHomeAssistant(host: String) -> ConnectionProblem {
        ConnectionProblem(
            title: "Not Home Assistant",
            message: "\(host) answered, but not like Home Assistant. Check the address and the port — Home Assistant usually listens on 8123."
        )
    }

    /// Home Assistant said no to the token. Its own words are quoted, so they can be searched.
    static func tokenRejected(reason: String?) -> ConnectionProblem {
        let quoted = reason.map { " (“\($0)”)" } ?? ""
        return ConnectionProblem(
            title: "Token Not Accepted",
            message: "Home Assistant turned the access token down\(quoted). Create a new long-lived access token on your profile page in Home Assistant and paste it again."
        )
    }

    static func noSignInAnswer(host: String) -> ConnectionProblem {
        ConnectionProblem(
            title: "No Answer to Sign-In",
            message: "\(host) stopped answering while signing in. Try again; if it keeps happening, restart Home Assistant."
        )
    }

    // MARK: - The network

    /// Maps a failed WebSocket attempt to what the person should check.
    ///
    /// - Parameters:
    ///   - error: what `URLSessionWebSocketTask` threw.
    ///   - statusCode: the HTTP status of the handshake, when the server answered one.
    ///   - url: the WebSocket address that was opened.
    static func describe(_ error: Error, statusCode: Int?, url: URL) -> ConnectionProblem {
        let host = url.host ?? url.absoluteString
        let local = isLocal(host)

        if let statusCode, statusCode >= 400 {
            switch statusCode {
            case 401, 403:
                return ConnectionProblem(
                    title: "Access Refused",
                    message: "\(host) refused the connection (HTTP \(statusCode)). If Home Assistant is behind a proxy, allow WebSocket connections there, and check that this device's address is not on Home Assistant's IP ban list."
                )
            case 404:
                return ConnectionProblem(
                    title: "Not Home Assistant",
                    message: "\(host) has no Home Assistant at this address (HTTP 404). Use the address you open Home Assistant with, without a page path."
                )
            default:
                return ConnectionProblem(
                    title: "Server Error",
                    message: "\(host) answered with HTTP \(statusCode). Check that Home Assistant is running, then try again."
                )
            }
        }

        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return couldNotConnect(host: host, error: error)
        }

        switch nsError.code {
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return ConnectionProblem(
                title: "Address Not Found",
                message: "Nothing answers to “\(host)”. Check the spelling. At home the address is often homeassistant.local:8123; away from home, use your remote address."
            )
        case NSURLErrorCannotConnectToHost:
            let port = url.port.map { "port \($0)" } ?? "that port"
            return ConnectionProblem(
                title: "Connection Refused",
                message: "\(host) is there, but nothing accepted the connection on \(port). Check the port, and that Home Assistant is running."
            )
        case NSURLErrorTimedOut:
            return ConnectionProblem(
                title: "No Answer",
                message: local
                    ? "\(host) did not answer in time. Check that this device is on the same network as Home Assistant, and that Local Network access is on for Home Sync Assistant in Settings."
                    : "\(host) did not answer in time. Check the address, and that Home Assistant can be reached from outside your home."
            )
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed,
             NSURLErrorInternationalRoamingOff:
            return ConnectionProblem(
                title: "No Network",
                message: local
                    ? "This device cannot reach \(host). Join the same network as Home Assistant, and check that Local Network access is on for Home Sync Assistant in Settings."
                    : "This device is not connected to a network that can reach \(host)."
            )
        case NSURLErrorAppTransportSecurityRequiresSecureConnection:
            return ConnectionProblem(
                title: "Secure Address Needed",
                message: "Plain http:// only works for addresses on your home network. For \(host), use its https:// address."
            )
        case NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid,
             NSURLErrorSecureConnectionFailed, NSURLErrorClientCertificateRejected,
             NSURLErrorClientCertificateRequired:
            return ConnectionProblem(
                title: "Certificate Not Trusted",
                message: "The secure connection to \(host) failed because its certificate is not trusted. Use a certificate this device trusts, or http:// for an address on your home network."
            )
        case NSURLErrorBadServerResponse:
            return notHomeAssistant(host: host)
        default:
            return couldNotConnect(host: host, error: error)
        }
    }

    private static func couldNotConnect(host: String, error: Error) -> ConnectionProblem {
        ConnectionProblem(
            title: "Could Not Connect",
            message: "Could not connect to \(host): \(error.localizedDescription)"
        )
    }

    /// A `.local` name or a private IPv4 address: the kind of host only reachable at home.
    static func isLocal(_ host: String) -> Bool {
        let host = host.lowercased()
        if host.hasSuffix(".local") || host == "localhost" || !host.contains(".") { return true }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        switch (parts[0], parts[1]) {
        case (10, _), (192, 168), (127, _): return true
        case (172, 16...31): return true
        case (169, 254): return true
        default: return false
        }
    }
}
