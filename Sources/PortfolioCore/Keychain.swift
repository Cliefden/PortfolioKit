import Foundation
import Security

/// A generic-password Keychain store scoped to one `service` (and optionally an
/// access group). Replaces the ~10 hand-rolled wrappers across the portfolio
/// (most complete source: Otta `KeychainService`; also Svamp, Ariman).
///
/// Writes are **update-then-add**: `SecItemUpdate` on the matching item, falling
/// back to `SecItemAdd` only when nothing matched. The match query never
/// contains `kSecValueData` — that was the bug in Otta's `KeychainHelper.save`
/// (its delete query included the *new* data, so the old item was never found,
/// never removed, and the following `SecItemAdd` failed as a duplicate).
///
/// ```swift
/// let keychain = Keychain(service: "se.crawik.otta")
/// try keychain.set("refresh-token", for: "session.refresh")
/// let token = try keychain.string(for: "session.refresh")
/// try keychain.set(session, for: "session")          // any Codable, JSON-encoded
/// let restored = try keychain.get(Session.self, for: "session")
/// try keychain.remove("session")
/// ```
///
/// All Security calls go through a ``KeychainBackend`` so the logic can be
/// unit-tested with ``InMemoryKeychainBackend`` (`swift test` on macOS has no
/// keychain entitlement and fails with `errSecMissingEntitlement`).
public struct Keychain: Sendable {
    /// When the item is readable. Maps 1:1 to the `kSecAttrAccessible*` constants.
    public enum Accessibility: Sendable, Hashable, CaseIterable {
        /// Only while the device is unlocked.
        case whenUnlocked
        /// After the first unlock following a boot — the portfolio default
        /// (background refresh / widgets can still read it).
        case afterFirstUnlock
        /// Like `.whenUnlocked`, never migrated to another device via backups.
        case whenUnlockedThisDeviceOnly
        /// Like `.afterFirstUnlock`, never migrated to another device via backups.
        case afterFirstUnlockThisDeviceOnly
        /// Only while unlocked and a passcode is set; deleted if the passcode is removed.
        case whenPasscodeSetThisDeviceOnly

        public var securityValue: CFString {
            switch self {
            case .whenUnlocked: kSecAttrAccessibleWhenUnlocked
            case .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlock
            case .whenUnlockedThisDeviceOnly: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            case .afterFirstUnlockThisDeviceOnly: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .whenPasscodeSetThisDeviceOnly: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            }
        }
    }

    public let service: String
    public let accessGroup: String?
    public let accessibility: Accessibility
    private let backend: any KeychainBackend

    /// - Parameters:
    ///   - service: `kSecAttrService` — usually the bundle identifier.
    ///   - accessGroup: shared keychain group (`TEAMID.group.id`), or `nil` for app-only.
    ///   - accessibility: applied on every write (also re-applied on update).
    ///   - backend: defaults to the real Security framework.
    public init(
        service: String,
        accessGroup: String? = nil,
        accessibility: Accessibility = .afterFirstUnlock,
        backend: any KeychainBackend = SecurityKeychainBackend()
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
        self.backend = backend
    }

    // MARK: Data

    /// Store `data` for `key`, replacing any existing value.
    public func set(_ data: Data, for key: String) throws {
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.securityValue,
        ]
        var status = backend.update(query, attributes: attributes)
        if status == errSecItemNotFound {
            status = backend.add(query.merging(attributes) { _, new in new })
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    /// The stored data, or `nil` when there is no item for `key`.
    public func data(for key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let (status, result) = backend.copyMatching(query)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.unexpectedData }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Whether an item exists for `key`. Errors (other than not-found) are
    /// rethrown so a corrupt/locked keychain doesn't masquerade as "absent".
    public func contains(_ key: String) throws -> Bool {
        try data(for: key) != nil
    }

    // MARK: String

    /// Store a UTF-8 string (raw bytes, not JSON).
    public func set(_ string: String, for key: String) throws {
        try set(Data(string.utf8), for: key)
    }

    /// The stored UTF-8 string, or `nil` when there is no item for `key`.
    public func string(for key: String) throws -> String? {
        guard let data = try data(for: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else { throw KeychainError.unexpectedData }
        return string
    }

    // MARK: Codable

    /// JSON-encode `value` and store it. (`Data` and `String` use the raw
    /// overloads above; this one is for structured values.)
    public func set<T: Encodable>(_ value: T, for key: String, encoder: JSONEncoder = JSONEncoder()) throws {
        try set(encoder.encode(value), for: key)
    }

    /// Decode a JSON value stored with ``set(_:for:encoder:)``; `nil` when absent.
    public func get<T: Decodable>(_ type: T.Type = T.self, for key: String, decoder: JSONDecoder = JSONDecoder()) throws -> T? {
        guard let data = try data(for: key) else { return nil }
        return try decoder.decode(T.self, from: data)
    }

    // MARK: Removal

    /// Delete the item for `key`. Removing a missing item is not an error.
    public func remove(_ key: String) throws {
        let status = backend.delete(baseQuery(for: key))
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Delete every generic password stored under this `service` (+ access group).
    /// Items from other services are untouched.
    public func removeAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        let status = backend.delete(query)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: Query

    /// The identifying attributes only — class, service, account (+ group).
    /// Never data or accessibility: those are attributes to *write*, and putting
    /// them in a match query makes the existing item invisible.
    func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }
}

/// Errors thrown by ``Keychain``.
public enum KeychainError: Error, Equatable, LocalizedError {
    /// A Security call returned this status (see `SecCopyErrorMessageString`).
    case unexpectedStatus(OSStatus)
    /// The stored bytes weren't the expected type (not `Data`, or not UTF-8).
    case unexpectedData

    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Keychain error: \(message)"
        case .unexpectedData:
            return "Unexpected data format in Keychain"
        }
    }
}

// MARK: - Backend

/// The four `SecItem*` calls ``Keychain`` needs, as a seam for tests.
/// Queries use the Security framework's own keys (`kSecClass`, `kSecAttrAccount`, …).
public protocol KeychainBackend: Sendable {
    func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?)
    func add(_ attributes: [String: Any]) -> OSStatus
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

/// The real Security-framework backend.
public struct SecurityKeychainBackend: KeychainBackend {
    public init() {}

    public func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) {
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result)
    }

    public func add(_ attributes: [String: Any]) -> OSStatus {
        SecItemAdd(attributes as CFDictionary, nil)
    }

    public func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    public func delete(_ query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}

/// An in-process keychain with the real matching semantics that matter here:
/// every attribute in a query (other than the `kSecReturn*`/`kSecMatch*`
/// controls) must equal the stored item's attribute, `SecItemAdd` of an item
/// whose class/service/account/group already exists fails with
/// `errSecDuplicateItem`, and delete removes every match. For tests and
/// previews.
public final class InMemoryKeychainBackend: KeychainBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [[String: Any]] = []

    public init() {}

    /// Number of stored items (all services).
    public var count: Int { lock.withLock { items.count } }

    private static let controlKeys: Set<String> = [
        kSecReturnData as String, kSecReturnAttributes as String,
        kSecReturnRef as String, kSecReturnPersistentRef as String,
        kSecMatchLimit as String,
    ]
    private static let identityKeys = [
        kSecClass as String, kSecAttrService as String,
        kSecAttrAccount as String, kSecAttrAccessGroup as String,
    ]

    private static func matches(_ item: [String: Any], _ query: [String: Any]) -> Bool {
        for (key, value) in query where !controlKeys.contains(key) {
            guard let stored = item[key], (stored as AnyObject).isEqual(value) else { return false }
        }
        return true
    }

    /// Same class/service/account/access group (absent on both counts as equal).
    private static func sameIdentity(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
        identityKeys.allSatisfy { key in
            switch (lhs[key], rhs[key]) {
            case (nil, nil): true
            case let (l?, r?): (l as AnyObject).isEqual(r)
            default: false
            }
        }
    }

    public func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) {
        lock.withLock {
            guard let item = items.first(where: { Self.matches($0, query) }) else {
                return (errSecItemNotFound, nil)
            }
            return (errSecSuccess, item[kSecValueData as String] as AnyObject?)
        }
    }

    public func add(_ attributes: [String: Any]) -> OSStatus {
        lock.withLock {
            if items.contains(where: { Self.sameIdentity($0, attributes) }) {
                return errSecDuplicateItem
            }
            items.append(attributes)
            return errSecSuccess
        }
    }

    public func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        lock.withLock {
            var found = false
            for index in items.indices where Self.matches(items[index], query) {
                items[index].merge(attributes) { _, new in new }
                found = true
            }
            return found ? errSecSuccess : errSecItemNotFound
        }
    }

    public func delete(_ query: [String: Any]) -> OSStatus {
        lock.withLock {
            let before = items.count
            items.removeAll { Self.matches($0, query) }
            return items.count == before ? errSecItemNotFound : errSecSuccess
        }
    }
}
