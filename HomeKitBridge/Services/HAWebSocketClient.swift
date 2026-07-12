import Foundation

enum HAConfiguration {
    static let defaultURL = ""
    static let defaultToken = ""
}

/// Home Assistant WebSocket API client.
/// Handles authentication, message IDs, and request/response matching.
@MainActor
final class HAWebSocketClient: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var connectionError: String?

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var nextId: Int = 1
    private var pendingHandlers: [Int: (Result<Any, Error>) -> Void] = [:]
    private var haURL: String { UserDefaults.standard.string(forKey: "haURL") ?? HAConfiguration.defaultURL }
    private var haToken: String { UserDefaults.standard.string(forKey: "haToken") ?? HAConfiguration.defaultToken }
    private var receiveTask: Task<Void, Never>?

    func connect() async -> Bool {
        disconnect()
        connectionError = nil

        let base = haURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let token = haToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !base.isEmpty, !token.isEmpty else {
            connectionError = "URL or token is empty"
            return false
        }

        let wsURL: String
        if base.hasPrefix("https://") {
            wsURL = "wss://" + base.dropFirst(8) + "/api/websocket"
        } else if base.hasPrefix("http://") {
            wsURL = "ws://" + base.dropFirst(7) + "/api/websocket"
        } else {
            wsURL = "ws://" + base + "/api/websocket"
        }

        guard let url = URL(string: wsURL) else {
            connectionError = "Invalid URL: \(wsURL)"
            return false
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.urlSession = session
        self.webSocket = task
        task.resume()

        // Wait for auth_required
        guard let authRequired = await receiveMessage(),
              let type = (authRequired as? [String: Any])?["type"] as? String,
              type == "auth_required" else {
            connectionError = "Did not receive auth_required"
            disconnect()
            return false
        }

        // Send auth
        let authMsg: [String: Any] = ["type": "auth", "access_token": token]
        guard let authData = try? JSONSerialization.data(withJSONObject: authMsg),
              let authStr = String(data: authData, encoding: .utf8) else {
            connectionError = "Failed to encode auth message"
            disconnect()
            return false
        }

        do {
            try await task.send(.string(authStr))
        } catch {
            connectionError = "Failed to send auth: \(error.localizedDescription)"
            disconnect()
            return false
        }

        // Wait for auth_ok or auth_invalid
        guard let authResult = await receiveMessage(),
              let resultType = (authResult as? [String: Any])?["type"] as? String else {
            connectionError = "No auth response"
            disconnect()
            return false
        }

        if resultType == "auth_ok" {
            isConnected = true
            connectionError = nil
            startReceiveLoop()
            return true
        } else {
            let msg = (authResult as? [String: Any])?["message"] as? String ?? "Unknown error"
            connectionError = "Auth failed: \(msg)"
            disconnect()
            return false
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isConnected = false
        pendingHandlers.removeAll()
        nextId = 1
    }

    /// Send a command and wait for its response.
    func sendCommand(_ payload: [String: Any]) async throws -> [String: Any] {
        guard let ws = webSocket, isConnected else {
            throw HAWSError.notConnected
        }

        let id = nextId
        nextId += 1

        var msg = payload
        msg["id"] = id

        let data = try JSONSerialization.data(withJSONObject: msg)
        guard let str = String(data: data, encoding: .utf8) else {
            throw HAWSError.encodingError
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingHandlers[id] = { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value as? [String: Any] ?? [:])
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            Task {
                do {
                    try await ws.send(.string(str))
                } catch {
                    self.pendingHandlers.removeValue(forKey: id)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Convenience methods

    /// Fetch area registry
    func fetchAreas() async throws -> [[String: Any]] {
        let result = try await sendCommand(["type": "config/area_registry/list"])
        return result["result"] as? [[String: Any]] ?? []
    }

    /// Fetch entity registry
    func fetchEntityRegistry() async throws -> [[String: Any]] {
        let result = try await sendCommand(["type": "config/entity_registry/list"])
        return result["result"] as? [[String: Any]] ?? []
    }

    /// Fetch device registry
    func fetchDeviceRegistry() async throws -> [[String: Any]] {
        let result = try await sendCommand(["type": "config/device_registry/list"])
        return result["result"] as? [[String: Any]] ?? []
    }

    /// Create an area
    func createArea(name: String) async throws -> [String: Any] {
        return try await sendCommand([
            "type": "config/area_registry/create",
            "name": name
        ])
    }

    /// Update an area
    func updateArea(areaId: String, name: String) async throws -> [String: Any] {
        return try await sendCommand([
            "type": "config/area_registry/update",
            "area_id": areaId,
            "name": name
        ])
    }

    /// Update entity registry entry (name, area_id, etc.)
    func updateEntity(entityId: String, updates: [String: Any]) async throws -> [String: Any] {
        var cmd: [String: Any] = [
            "type": "config/entity_registry/update",
            "entity_id": entityId
        ]
        for (key, value) in updates {
            cmd[key] = value
        }
        return try await sendCommand(cmd)
    }

    /// Get states
    func getStates() async throws -> [[String: Any]] {
        let result = try await sendCommand(["type": "get_states"])
        return result["result"] as? [[String: Any]] ?? []
    }

    // MARK: - Private

    private func receiveMessage() async -> Any? {
        guard let ws = webSocket else { return nil }
        do {
            let message = try await ws.receive()
            switch message {
            case .string(let text):
                return try JSONSerialization.jsonObject(with: Data(text.utf8))
            case .data(let data):
                return try JSONSerialization.jsonObject(with: data)
            @unknown default:
                return nil
            }
        } catch {
            return nil
        }
    }

    private func startReceiveLoop() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let ws = self.webSocket else { break }
                do {
                    let message = try await ws.receive()
                    let parsed: [String: Any]?
                    switch message {
                    case .string(let text):
                        parsed = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
                    case .data(let data):
                        parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    @unknown default:
                        parsed = nil
                    }

                    guard let msg = parsed else { continue }

                    if let id = msg["id"] as? Int, let handler = self.pendingHandlers.removeValue(forKey: id) {
                        if msg["success"] as? Bool == true {
                            handler(.success(msg))
                        } else {
                            let errorMsg = (msg["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                            handler(.failure(HAWSError.haError(errorMsg)))
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isConnected = false
                        self.connectionError = "Connection lost: \(error.localizedDescription)"
                    }
                    // Notify all pending handlers
                    await MainActor.run {
                        for (_, handler) in self.pendingHandlers {
                            handler(.failure(HAWSError.notConnected))
                        }
                        self.pendingHandlers.removeAll()
                    }
                    break
                }
            }
        }
    }
}

enum HAWSError: LocalizedError {
    case notConnected
    case encodingError
    case haError(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to Home Assistant"
        case .encodingError: return "Failed to encode message"
        case .haError(let msg): return "HA error: \(msg)"
        }
    }
}
