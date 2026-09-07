import Foundation

/// Where the shared copy of the configuration lives.
///
/// The app keeps its own copy in `UserDefaults` and mirrors it here, so a second
/// device sees the same servers, addresses and pairings. Tokens do not travel this
/// way — see `TokenStore`.
protocol ConfigurationSyncStore: AnyObject {
    var isAvailable: Bool { get }
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    /// Called when another device changed the shared copy.
    var onExternalChange: (() -> Void)? { get set }
    func startObserving()
}

/// iCloud's key-value store: small, free, and already tied to the person's account.
final class UbiquitousConfigurationSyncStore: ConfigurationSyncStore {
    var onExternalChange: (() -> Void)?

    private let store = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    /// False when the person is signed out of iCloud, or iCloud Drive is off. The
    /// app keeps working; it just stops sharing.
    var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    func data(forKey key: String) -> Data? {
        store.data(forKey: key)
    }

    func set(_ data: Data, forKey key: String) {
        store.set(data, forKey: key)
        store.synchronize()
    }

    func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.onExternalChange?()
        }
        store.synchronize()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

/// Where access tokens live: the keychain, marked synchronizable so they travel
/// through the iCloud keychain rather than plain key-value storage.
protocol TokenStore: AnyObject {
    func token(forServerId id: UUID) -> String?
    func setToken(_ token: String, forServerId id: UUID)
    func removeToken(forServerId id: UUID)
}

final class KeychainTokenStore: TokenStore {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.panta.homekitsync") {
        self.service = service
    }

    func token(forServerId id: UUID) -> String? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    func setToken(_ token: String, forServerId id: UUID) {
        guard !token.isEmpty else {
            removeToken(forServerId: id)
            return
        }

        let data = Data(token.utf8)
        let query = baseQuery(for: id)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)

        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    func removeToken(forServerId id: UUID) {
        SecItemDelete(baseQuery(for: id) as CFDictionary)
    }

    private func baseQuery(for id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            // The point of the exercise: this is what makes the token follow the
            // person to their other devices.
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
    }
}
