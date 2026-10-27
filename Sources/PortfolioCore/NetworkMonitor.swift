import Foundation
import Network
import Observation

/// Observable network reachability (`NWPathMonitor`), merged from Stokked and
/// Carpe Vitem's identical `NetworkMonitor`s.
///
/// ```swift
/// if NetworkMonitor.shared.isConnected { await sync.pushPending() }
///
/// // SwiftUI — observed automatically
/// Text(NetworkMonitor.shared.isConnected ? "Online" : "Offline")
/// ```
@Observable
@MainActor
public final class NetworkMonitor {
    public enum ConnectionType: String, Sendable, Hashable {
        case wifi, cellular, wired, other, none
    }

    /// The app-wide monitor, started on first access. Assumes "connected" until
    /// the first path update (Carpe Vitem's behaviour) — check
    /// ``hasReceivedInitialUpdate`` when that matters (Stokked starts offline).
    public static let shared = NetworkMonitor()

    /// Whether the current path is satisfied.
    public private(set) var isConnected: Bool
    /// Cellular / personal hotspot — avoid large uploads.
    public private(set) var isExpensive = false
    /// Low Data Mode is on.
    public private(set) var isConstrained = false
    public private(set) var connectionType: ConnectionType = .other
    /// `false` until `NWPathMonitor` has reported once.
    public private(set) var hasReceivedInitialUpdate = false

    /// Debug/screenshot override: report "offline" regardless of the path
    /// (Stokked's `simulateOffline`). Setting it updates `isConnected` at once.
    public var simulateOffline = false {
        didSet { isConnected = !simulateOffline && lastSatisfied }
    }

    @ObservationIgnored private var lastSatisfied: Bool
    @ObservationIgnored private let monitor = NWPathMonitor()

    /// - Parameter assumeConnected: the value of ``isConnected`` before the first update.
    public init(assumeConnected: Bool = true) {
        isConnected = assumeConnected
        lastSatisfied = assumeConnected
        monitor.pathUpdateHandler = { [weak self] path in
            let update = PathUpdate(path)
            Task { @MainActor [weak self] in self?.apply(update) }
        }
        monitor.start(queue: DispatchQueue(label: "PortfolioCore.NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }

    private func apply(_ update: PathUpdate) {
        lastSatisfied = update.satisfied
        isConnected = update.satisfied && !simulateOffline
        isExpensive = update.isExpensive
        isConstrained = update.isConstrained
        connectionType = update.connectionType
        hasReceivedInitialUpdate = true
    }

    /// Sendable snapshot of an `NWPath`, taken on the monitor's queue.
    struct PathUpdate: Sendable {
        var satisfied: Bool
        var isExpensive: Bool
        var isConstrained: Bool
        var connectionType: ConnectionType

        init(satisfied: Bool, isExpensive: Bool, isConstrained: Bool, connectionType: ConnectionType) {
            self.satisfied = satisfied
            self.isExpensive = isExpensive
            self.isConstrained = isConstrained
            self.connectionType = connectionType
        }

        init(_ path: NWPath) {
            let satisfied = path.status == .satisfied
            self.init(
                satisfied: satisfied,
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained,
                connectionType: Self.connectionType(
                    satisfied: satisfied,
                    wifi: path.usesInterfaceType(.wifi),
                    cellular: path.usesInterfaceType(.cellular),
                    wired: path.usesInterfaceType(.wiredEthernet)
                )
            )
        }

        static func connectionType(satisfied: Bool, wifi: Bool, cellular: Bool, wired: Bool) -> ConnectionType {
            guard satisfied else { return .none }
            if wifi { return .wifi }
            if cellular { return .cellular }
            if wired { return .wired }
            return .other
        }
    }
}
