import Foundation
import Network

enum BridgeError: LocalizedError {
    case notFound(String)
    case badRequest(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let msg): return msg
        case .badRequest(let msg): return msg
        }
    }
}

@MainActor
final class HTTPServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var port: Int {
        didSet { UserDefaults.standard.set(port, forKey: "serverPort") }
    }

    private let homeKit: HomeKitManager
    private let logStore: LogStore
    private var listener: NWListener?

    init(homeKit: HomeKitManager, logStore: LogStore) {
        self.homeKit = homeKit
        self.logStore = logStore
        let saved = UserDefaults.standard.integer(forKey: "serverPort")
        self.port = saved == 0 ? 8400 : saved
    }

    func start() {
        guard !isRunning else { return }

        do {
            let params = NWParameters.tcp
            let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) ?? 8400
            let listener = try NWListener(using: params, on: nwPort)
            self.listener = listener

            listener.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in
                    self?.handle(connection: conn)
                }
            }

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.logStore.add(category: .server, message: "HTTP server started", details: "Port \(self?.port ?? 0)")
                    case .failed(let err):
                        self?.isRunning = false
                        self?.logStore.add(category: .error, message: "HTTP server failed", details: err.localizedDescription)
                    case .cancelled:
                        self?.isRunning = false
                        self?.logStore.add(category: .server, message: "HTTP server stopped")
                    default:
                        break
                    }
                }
            }

            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            logStore.add(category: .error, message: "Failed to start HTTP server", details: error.localizedDescription)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            Task { @MainActor in
                let response = await self.route(request)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func route(_ request: String) async -> Data {
        do {
            let lines = request.components(separatedBy: "\r\n")
            guard let first = lines.first else { throw BridgeError.badRequest("Invalid request") }
            let parts = first.split(separator: " ")
            guard parts.count >= 2 else { throw BridgeError.badRequest("Invalid request line") }
            let method = String(parts[0])
            let path = String(parts[1])

            let body: Data
            if let range = request.range(of: "\r\n\r\n") {
                body = Data(request[range.upperBound...].utf8)
            } else {
                body = Data()
            }

            switch (method, path) {
            case ("GET", "/api/homes"):
                let homes = homeKit.homes.map { [
                    "id": $0.uniqueIdentifier.uuidString,
                    "name": $0.name,
                    "roomCount": $0.rooms.count,
                    "accessoryCount": $0.accessories.count
                ] }
                return httpResponse(200, body: ["homes": homes])

            case ("GET", let p) where p.hasPrefix("/api/homes/") && p.hasSuffix("/accessories/serials"):
                let homeId = extractId(from: p, prefix: "/api/homes/", suffix: "/accessories/serials")
                guard let accessories = await homeKit.accessoriesWithSerial(forHomeId: homeId) else {
                    throw BridgeError.notFound("Home not found")
                }
                return httpResponse(200, body: ["accessories": accessories])

            case ("GET", let p) where p.hasPrefix("/api/homes/") && p.hasSuffix("/accessories"):
                let homeId = extractId(from: p, prefix: "/api/homes/", suffix: "/accessories")
                guard let home = homeKit.home(byId: homeId) else {
                    throw BridgeError.notFound("Home not found")
                }
                var accessories: [[String: Any]] = []
                for a in home.accessories {
                    let serial = await homeKit.readSerialNumber(for: a)
                    accessories.append([
                        "id": a.uniqueIdentifier.uuidString,
                        "name": a.name,
                        "room": a.room?.name ?? "Default Room",
                        "manufacturer": a.manufacturer,
                        "model": a.model,
                        "serialNumber": serial
                    ])
                }
                return httpResponse(200, body: ["accessories": accessories])

            case ("GET", let p) where p.hasPrefix("/api/accessories/") && p.hasSuffix("/serial"):
                let id = extractId(from: p, prefix: "/api/accessories/", suffix: "/serial")
                guard let accessory = homeKit.accessory(byId: id) else {
                    throw BridgeError.notFound("Accessory not found")
                }
                let serial = await homeKit.readSerialNumber(for: accessory)
                return httpResponse(200, body: ["id": id, "serialNumber": serial])

            case ("POST", let p) where p.hasPrefix("/api/accessories/") && p.hasSuffix("/move"):
                let id = extractId(from: p, prefix: "/api/accessories/", suffix: "/move")
                let json = try decodeJSON(body)
                guard let roomId = json["roomId"] as? String else {
                    throw BridgeError.badRequest("Missing roomId")
                }
                try await homeKit.moveAccessory(id: id, toRoomId: roomId)
                return httpResponse(200, body: ["success": true])

            case ("POST", let p) where p.hasPrefix("/api/accessories/") && p.hasSuffix("/rename"):
                let id = extractId(from: p, prefix: "/api/accessories/", suffix: "/rename")
                let json = try decodeJSON(body)
                guard let newName = json["name"] as? String else {
                    throw BridgeError.badRequest("Missing name")
                }
                try await homeKit.renameAccessory(id: id, newName: newName)
                return httpResponse(200, body: ["success": true])

            default:
                throw BridgeError.notFound("Route not found")
            }
        } catch let error as BridgeError {
            switch error {
            case .notFound(let msg): return httpResponse(404, body: ["error": msg])
            case .badRequest(let msg): return httpResponse(400, body: ["error": msg])
            }
        } catch {
            return httpResponse(500, body: ["error": error.localizedDescription])
        }
    }

    private func extractId(from path: String, prefix: String, suffix: String) -> String {
        String(path.dropFirst(prefix.count).dropLast(suffix.count))
    }

    private func decodeJSON(_ data: Data) throws -> [String: Any] {
        guard !data.isEmpty else { return [:] }
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }

    private func httpResponse(_ code: Int, body: [String: Any]) -> Data {
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted])) ?? Data()
        let reason: String
        switch code {
        case 200: reason = "OK"
        case 400: reason = "Bad Request"
        case 404: reason = "Not Found"
        default: reason = "Internal Server Error"
        }
        let header = "HTTP/1.1 \(code) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
        return Data(header.utf8) + data
    }
}
