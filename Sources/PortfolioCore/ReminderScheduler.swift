import Foundation
import UserNotifications

/// The slice of `UNUserNotificationCenter` the scheduler needs — a seam for tests.
public protocol NotificationCenterProtocol: Sendable {
    func pendingRequestIdentifiers() async -> [String]
    func removePendingRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

/// The real notification center. Resolves `UNUserNotificationCenter.current()`
/// per call, so the value itself is trivially `Sendable`.
public struct SystemNotificationCenter: NotificationCenterProtocol {
    public init() {}

    public func pendingRequestIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    public func removePendingRequests(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
}

/// Reconciles an app's pending **local** notifications with a freshly computed
/// plan, scoped by identifier prefix — the "remove-by-prefix → re-add" loop in
/// Jeroboam `DrinkingWindowNotificationService`, ThenCam `SceneReminderCenter`,
/// Carpe Vitem, Stokked and Contrarian `DailyReminder`.
///
/// Only identifiers starting with `prefix` are ever touched, so several
/// features (and other code) can share the 64-request system budget safely.
///
/// ```swift
/// let scheduler = ReminderScheduler()
/// let requests = plan.map { reminder in
///     UNNotificationRequest(
///         identifier: "drinking-window." + reminder.id,
///         content: reminder.content,
///         trigger: UNCalendarNotificationTrigger(dateMatching: reminder.components, repeats: false))
/// }
/// await scheduler.reschedule(prefix: "drinking-window.", requests: requests, limit: 48)
/// ```
public struct ReminderScheduler: Sendable {
    /// What a ``ReminderScheduler/reschedule(prefix:requests:limit:)`` pass did.
    public struct Reconciliation: Sendable, Equatable {
        /// Pending identifiers (with the prefix) that were no longer planned.
        public var removed: [String]
        /// Identifiers handed to the center (adding an existing identifier
        /// replaces that request, so unchanged reminders are refreshed in place).
        public var added: [String]
        /// Requests dropped because they don't start with the prefix (they
        /// could never be cleaned up) or exceed `limit`.
        public var skipped: [String]
        /// Requests the center rejected.
        public var failed: [String]
    }

    private let center: any NotificationCenterProtocol

    public init(center: any NotificationCenterProtocol = SystemNotificationCenter()) {
        self.center = center
    }

    /// Replace every pending request whose identifier starts with `prefix` by
    /// `requests`: stale ones are removed, the new set is (re-)added.
    ///
    /// - Parameter limit: cap on how many of `requests` are scheduled (keep the
    ///   plan sorted soonest-first). iOS keeps at most 64 pending per app.
    @discardableResult
    public func reschedule(prefix: String, requests: [UNNotificationRequest], limit: Int? = nil) async -> Reconciliation {
        precondition(!prefix.isEmpty, "An empty prefix would match every pending notification")
        var skipped: [String] = []
        var planned: [UNNotificationRequest] = []
        var seen = Set<String>()
        for request in requests {
            let id = request.identifier
            guard id.hasPrefix(prefix), !seen.contains(id) else { skipped.append(id); continue }
            if let limit, planned.count >= limit { skipped.append(id); continue }
            seen.insert(id)
            planned.append(request)
        }

        let pending = await center.pendingRequestIdentifiers()
        let stale = pending.filter { $0.hasPrefix(prefix) && !seen.contains($0) }
        if !stale.isEmpty { center.removePendingRequests(withIdentifiers: stale) }

        var added: [String] = []
        var failed: [String] = []
        for request in planned {
            if Task.isCancelled { break }
            do {
                try await center.add(request)
                added.append(request.identifier)
            } catch {
                failed.append(request.identifier)
            }
        }
        return Reconciliation(removed: stale, added: added, skipped: skipped, failed: failed)
    }

    /// Remove every pending request whose identifier starts with `prefix`
    /// (e.g. when the user turns the feature off). Returns the removed identifiers.
    @discardableResult
    public func removeAll(prefix: String) async -> [String] {
        await reschedule(prefix: prefix, requests: []).removed
    }
}
