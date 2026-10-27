import Foundation
import Testing
import UserNotifications
@testable import PortfolioCore

final class FakeNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [String] = []
    private(set) var removedBatches: [[String]] = []
    var rejecting: Set<String> = []

    init(pending: [String] = []) { self.pending = pending }

    var identifiers: [String] { lock.withLock { pending } }

    func pendingRequestIdentifiers() async -> [String] { lock.withLock { pending } }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        lock.withLock {
            removedBatches.append(identifiers)
            pending.removeAll { identifiers.contains($0) }
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        let id = request.identifier
        try lock.withLock {
            if rejecting.contains(id) { throw CocoaError(.validationStringTooLong) }
            if !pending.contains(id) { pending.append(id) } // same id replaces
        }
    }
}

private func request(_ id: String) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = id
    var components = DateComponents()
    components.hour = 10
    return UNNotificationRequest(
        identifier: id, content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    )
}

@Suite struct ReminderSchedulerTests {
    @Test func removesStaleAndAddsNew() async {
        let center = FakeNotificationCenter(pending: ["wine.a", "wine.b", "other.x"])
        let result = await ReminderScheduler(center: center)
            .reschedule(prefix: "wine.", requests: [request("wine.b"), request("wine.c")])
        #expect(result.removed == ["wine.a"])
        #expect(result.added == ["wine.b", "wine.c"])
        #expect(Set(center.identifiers) == ["wine.b", "wine.c", "other.x"])
    }

    @Test func neverTouchesOtherPrefixes() async {
        let center = FakeNotificationCenter(pending: ["other.1", "other.2"])
        await ReminderScheduler(center: center).reschedule(prefix: "mine.", requests: [])
        #expect(center.identifiers == ["other.1", "other.2"])
        #expect(center.removedBatches.isEmpty)
    }

    @Test func skipsForeignPrefixDuplicatesAndOverLimit() async {
        let center = FakeNotificationCenter()
        let result = await ReminderScheduler(center: center).reschedule(
            prefix: "r.",
            requests: [request("r.1"), request("x.1"), request("r.1"), request("r.2"), request("r.3")],
            limit: 2
        )
        #expect(result.added == ["r.1", "r.2"])
        #expect(result.skipped == ["x.1", "r.1", "r.3"])
        #expect(center.identifiers == ["r.1", "r.2"])
    }

    @Test func reportsFailures() async {
        let center = FakeNotificationCenter()
        center.rejecting = ["r.bad"]
        let result = await ReminderScheduler(center: center)
            .reschedule(prefix: "r.", requests: [request("r.ok"), request("r.bad")])
        #expect(result.added == ["r.ok"])
        #expect(result.failed == ["r.bad"])
    }

    @Test func removeAllByPrefix() async {
        let center = FakeNotificationCenter(pending: ["r.1", "r.2", "keep"])
        let removed = await ReminderScheduler(center: center).removeAll(prefix: "r.")
        #expect(removed == ["r.1", "r.2"])
        #expect(center.identifiers == ["keep"])
    }
}
