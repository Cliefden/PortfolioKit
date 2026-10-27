import Foundation
import Security
import Testing
@testable import PortfolioCore

@Suite struct KeychainTests {
    let backend = InMemoryKeychainBackend()
    var keychain: Keychain { Keychain(service: "test.service", backend: backend) }

    @Test func roundTripsData() throws {
        try keychain.set(Data([1, 2, 3]), for: "k")
        #expect(try keychain.data(for: "k") == Data([1, 2, 3]))
        #expect(try keychain.contains("k"))
    }

    @Test func missingKeyIsNilNotError() throws {
        #expect(try keychain.data(for: "nope") == nil)
        #expect(try keychain.string(for: "nope") == nil)
        #expect(try !keychain.contains("nope"))
    }

    /// The Otta `KeychainHelper` bug: overwriting must replace, not fail as a duplicate.
    @Test func overwriteUpdatesInPlace() throws {
        try keychain.set("first", for: "token")
        try keychain.set("second", for: "token")
        #expect(try keychain.string(for: "token") == "second")
        #expect(backend.count == 1)
    }

    @Test func matchQueryNeverContainsValueData() {
        let query = keychain.baseQuery(for: "k")
        #expect(query[kSecValueData as String] == nil)
        #expect(query[kSecAttrAccessible as String] == nil)
        #expect(query[kSecAttrAccount as String] as? String == "k")
        #expect(query[kSecAttrService as String] as? String == "test.service")
    }

    @Test func stringsAreStoredAsRawUTF8() throws {
        try keychain.set("hello", for: "s")
        #expect(try keychain.data(for: "s") == Data("hello".utf8))
    }

    @Test func codableRoundTrip() throws {
        struct Session: Codable, Equatable { var user: String; var expires: Int }
        try keychain.set(Session(user: "u1", expires: 42), for: "session")
        #expect(try keychain.get(Session.self, for: "session") == Session(user: "u1", expires: 42))
        #expect(try keychain.get(Session.self, for: "absent") == nil)
    }

    @Test func removeIsIdempotent() throws {
        try keychain.set("x", for: "k")
        try keychain.remove("k")
        try keychain.remove("k")
        #expect(try keychain.data(for: "k") == nil)
    }

    @Test func removeAllOnlyTouchesOwnService() throws {
        let other = Keychain(service: "other.service", backend: backend)
        try keychain.set("a", for: "1")
        try keychain.set("b", for: "2")
        try other.set("c", for: "1")
        try keychain.removeAll()
        #expect(try keychain.data(for: "1") == nil)
        #expect(try keychain.data(for: "2") == nil)
        #expect(try other.string(for: "1") == "c")
    }

    @Test func servicesAndGroupsAreIsolated() throws {
        let grouped = Keychain(service: "test.service", accessGroup: "TEAM.group", backend: backend)
        try keychain.set("plain", for: "k")
        try grouped.set("grouped", for: "k")
        #expect(try grouped.string(for: "k") == "grouped")
        #expect(backend.count == 2)
    }

    @Test func accessibilityIsWritten() throws {
        let strict = Keychain(service: "s", accessibility: .whenUnlockedThisDeviceOnly, backend: backend)
        try strict.set("x", for: "k")
        #expect(Keychain.Accessibility.whenUnlockedThisDeviceOnly.securityValue == kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    }

    @Test func surfacesBackendErrors() {
        struct Failing: KeychainBackend {
            func copyMatching(_ query: [String: Any]) -> (OSStatus, AnyObject?) { (errSecInteractionNotAllowed, nil) }
            func add(_ attributes: [String: Any]) -> OSStatus { errSecDuplicateItem }
            func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus { errSecItemNotFound }
            func delete(_ query: [String: Any]) -> OSStatus { errSecAuthFailed }
        }
        let keychain = Keychain(service: "s", backend: Failing())
        #expect(throws: KeychainError.unexpectedStatus(errSecInteractionNotAllowed)) { try keychain.data(for: "k") }
        #expect(throws: KeychainError.unexpectedStatus(errSecDuplicateItem)) { try keychain.set("x", for: "k") }
        #expect(throws: KeychainError.unexpectedStatus(errSecAuthFailed)) { try keychain.remove("k") }
    }

    /// The in-memory backend reproduces the real duplicate semantics, so the
    /// buggy delete-then-add pattern would fail here too.
    @Test func backendRejectsDuplicateAdd() {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "s",
            kSecAttrAccount as String: "k",
            kSecValueData as String: Data([1]),
        ]
        #expect(backend.add(attributes) == errSecSuccess)
        var buggyDelete = attributes
        buggyDelete[kSecValueData as String] = Data([2]) // the *new* value
        #expect(backend.delete(buggyDelete) == errSecItemNotFound)
        var second = attributes
        second[kSecValueData as String] = Data([2])
        #expect(backend.add(second) == errSecDuplicateItem)
    }
}
