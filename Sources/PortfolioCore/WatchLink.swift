#if canImport(WatchConnectivity) && (os(iOS) || os(watchOS))
import Foundation
import Observation
import WatchConnectivity

/// Property-list payloads are value types in practice; this box lets them cross
/// from WatchConnectivity's delegate queue to the main actor.
private struct PlistBox: @unchecked Sendable {
    let value: [String: Any]
}

/// The shared WatchConnectivity bridge for iPhone ↔ Apple Watch, distilled from
/// Sextant `WatchLink`, Lunker `WatchSync` and Equinox `WatchSync`.
///
/// - **Application context** (`updateContext`) — latest-value-wins state,
///   delivered in the background even when the counterpart app isn't running.
///   Keys are *merged* into the last context (one dictionary is shared by every
///   producer), a `sentAt` timestamp is added so an identical payload is still
///   delivered, and the update is held as pending until the session is
///   activated (and, on iPhone, the watch app is installed).
/// - **Messages** (`send`) — live `sendMessage` when reachable; otherwise (or
///   when the live send fails) queued with `transferUserInfo`, which the system
///   delivers FIFO when the counterpart wakes. Messages sent before activation
///   are queued in memory and flushed on activation.
/// - **Receiving** — install `onContext` / `onMessage`. Anything received before
///   a handler exists is buffered and replayed when it's set.
///
/// ```swift
/// // both sides, at launch
/// WatchLink.shared.activate()
///
/// // phone
/// WatchLink.shared.updateContext(["snapshot": try JSONEncoder().encode(snapshot)])
/// WatchLink.shared.onMessage = { message in handleWatchAction(message) }
///
/// // watch
/// WatchLink.shared.onContext = { context in
///     if let data = context["snapshot"] as? Data { model.apply(data) }
/// }
/// WatchLink.shared.send(["type": "mob", "at": Date().timeIntervalSince1970])
/// ```
@MainActor
@Observable
public final class WatchLink: NSObject {
    public static let shared = WatchLink()

    /// Key added to every outgoing context (seconds since 1970).
    public nonisolated static let sentAtKey = "sentAt"

    public private(set) var activationState: WCSessionActivationState = .notActivated
    public private(set) var isReachable = false
    /// The last error from WatchConnectivity, for diagnostics.
    public private(set) var lastError: String?
    /// The latest application context received from the counterpart.
    @ObservationIgnored public private(set) var receivedContext: [String: Any] = [:]

    /// Called with each received application context (also replayed with the
    /// latest one when the handler is set).
    @ObservationIgnored public var onContext: (([String: Any]) -> Void)? {
        didSet { if let onContext, !receivedContext.isEmpty { onContext(receivedContext) } }
    }

    /// Called with each received message / user-info transfer. Messages that
    /// arrive before a handler is set are buffered and replayed in order.
    @ObservationIgnored public var onMessage: (([String: Any]) -> Void)? {
        didSet { flushInbox() }
    }

    @ObservationIgnored private var inbox: [[String: Any]] = []
    @ObservationIgnored private var outbox: [(message: [String: Any], reliable: Bool)] = []
    @ObservationIgnored private var pendingContext: [String: Any]?
    @ObservationIgnored private var lastSentContext: [String: Any] = [:]

    override private init() {
        super.init()
    }

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    /// Activate the session. Idempotent — call it at launch on both sides.
    public func activate() {
        guard let session else { return }
        if session.delegate === self, session.activationState == .activated { return }
        session.delegate = self
        session.activate()
    }

    // MARK: Application context

    /// Merge `values` into the outgoing application context and push it.
    /// Pass `replacing: true` to drop keys from earlier updates.
    public func updateContext(_ values: [String: Any], replacing: Bool = false) {
        guard let session else { return }
        var context = replacing ? [:] : (pendingContext ?? lastSentContext)
        context.merge(values) { _, new in new }
        context[Self.sentAtKey] = Date().timeIntervalSince1970
        pendingContext = context
        if session.activationState == .activated {
            flushContext()
        } else {
            activate()
        }
    }

    private func flushContext() {
        guard let session, let context = pendingContext, session.activationState == .activated else { return }
        #if os(iOS)
        // Not paired / watch app not installed: keep it pending —
        // `sessionWatchStateDidChange` retries.
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        do {
            try session.updateApplicationContext(context)
            lastSentContext = context
            pendingContext = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Messages

    /// Send a message. Live when reachable; with `reliable` (the default) it
    /// falls back to `transferUserInfo` so it's delivered when the counterpart
    /// next wakes. Live-only messages (`reliable: false`) are dropped when the
    /// counterpart isn't reachable — use that for state that would be
    /// misleading if delivered late.
    public func send(_ message: [String: Any], reliable: Bool = true) {
        guard let session else { return }
        guard session.activationState == .activated else {
            outbox.append((message, reliable))
            activate()
            return
        }
        deliverOut(message, reliable: reliable, on: session)
    }

    private func deliverOut(_ message: [String: Any], reliable: Bool, on session: WCSession) {
        if session.isReachable {
            let box = PlistBox(value: message)
            session.sendMessage(message, replyHandler: nil) { [weak self] error in
                let description = error.localizedDescription
                Task { @MainActor in
                    self?.lastError = description
                    if reliable { WCSession.default.transferUserInfo(box.value) }
                }
            }
        } else if reliable {
            session.transferUserInfo(message)
        }
    }

    private func flushOutbox() {
        guard let session, session.activationState == .activated, !outbox.isEmpty else { return }
        let queued = outbox
        outbox.removeAll()
        for item in queued { deliverOut(item.message, reliable: item.reliable, on: session) }
    }

    // MARK: Receiving

    private func receive(message: [String: Any]) {
        if let onMessage { onMessage(message) } else { inbox.append(message) }
    }

    private func receive(context: [String: Any]) {
        guard !context.isEmpty else { return }
        receivedContext = context
        onContext?(context)
    }

    private func flushInbox() {
        guard let onMessage, !inbox.isEmpty else { return }
        let queued = inbox
        inbox.removeAll()
        queued.forEach(onMessage)
    }

    fileprivate func didActivate(state: WCSessionActivationState, reachable: Bool, context: PlistBox, error: String?) {
        activationState = state
        isReachable = reachable
        if let error { lastError = error }
        guard state == .activated else { return }
        receive(context: context.value)
        flushContext()
        flushOutbox()
    }

    fileprivate func setReachable(_ reachable: Bool) {
        isReachable = reachable
        if reachable { flushContext() }
    }

    fileprivate func received(context: PlistBox) { receive(context: context.value) }
    fileprivate func received(message: PlistBox) { receive(message: message.value) }

    #if os(iOS)
    fileprivate func watchStateChanged() { flushContext() }

    fileprivate func didDeactivate() {
        // The user switched to another Apple Watch: resend the latest context
        // to the new one once the session reactivates.
        activationState = .notActivated
        if pendingContext == nil, !lastSentContext.isEmpty { pendingContext = lastSentContext }
        WCSession.default.activate()
    }
    #endif
}

// WatchConnectivity calls these on a background queue: pull out plain values,
// then hop to the main actor. The non-Sendable `WCSession` is never captured.
extension WatchLink: WCSessionDelegate {
    public nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        let context = PlistBox(value: session.receivedApplicationContext)
        let message = error?.localizedDescription
        Task { @MainActor in
            self.didActivate(state: activationState, reachable: reachable, context: context, error: message)
        }
    }

    public nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.setReachable(reachable) }
    }

    public nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let box = PlistBox(value: applicationContext)
        Task { @MainActor in self.received(context: box) }
    }

    public nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let box = PlistBox(value: message)
        Task { @MainActor in self.received(message: box) }
    }

    public nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let box = PlistBox(value: userInfo)
        Task { @MainActor in self.received(message: box) }
    }

    #if os(iOS)
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in self.didDeactivate() }
    }

    public nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.watchStateChanged() }
    }
    #endif
}
#endif
