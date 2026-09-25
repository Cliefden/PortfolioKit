import SwiftUI

/// Where an active subscription was purchased. Drives *compliant* management UI:
/// App Store guidelines require StoreKit subs to be cancelled in the system
/// Settings (never an in-app "cancel"), while web/Stripe subs are managed via a
/// billing portal. (Genericized from Contrarian's source-aware paywall + Stokked's
/// `hasUnlimitedSubscription` gating and Nassau's manage/restore section.)
public enum SubscriptionSource: Sendable, Hashable {
    /// Purchased via StoreKit / the App Store. Manage with the native
    /// `.manageSubscriptionsSheet` — do **not** offer an in-app cancel.
    case storeKit
    /// Purchased on the web (e.g. Stripe). Manage via the billing portal.
    case web
    /// Complimentary / admin-granted access. No management affordance.
    case complimentary
}

/// The subscription facts the card needs. The app maps its own model onto this;
/// PortfolioKit stays backend-free.
public struct SubscriptionState: Sendable, Hashable {
    public var isActive: Bool
    /// Where an *active* subscription came from. Ignored when `isActive == false`.
    public var source: SubscriptionSource
    /// e.g. `"Renews 5 Jan 2027"` or `"Lifetime"`. Shown as the card detail when active.
    public var renewalDescription: String?

    public init(isActive: Bool, source: SubscriptionSource = .storeKit, renewalDescription: String? = nil) {
        self.isActive = isActive
        self.source = source
        self.renewalDescription = renewalDescription
    }

    public static let inactive = SubscriptionState(isActive: false)
}

/// A subscription status block: a tinted `StatusCard` plus the *compliant* action
/// for the current state — Upgrade when inactive, source-appropriate Manage when
/// active, and an always-available Restore. The app supplies the closures; this
/// view only decides which affordance is correct for the state/source.
public struct SubscriptionStatusCard: View {
    private let state: SubscriptionState
    private let planName: String
    private let onUpgrade: () -> Void
    private let onManage: () -> Void
    private let onRestore: (() -> Void)?
    private let isRestoring: Bool

    /// - Parameters:
    ///   - state: current subscription facts.
    ///   - planName: brand name of the paid tier, e.g. `"Plus"`, `"Pro"`.
    ///   - isRestoring: show a spinner + disable the Restore button while true.
    ///   - onUpgrade: present the paywall (shown when inactive).
    ///   - onManage: manage the active sub. For `.storeKit` wire the native
    ///     `.manageSubscriptionsSheet`; for `.web` open the billing portal.
    ///   - onRestore: restore purchases. Pass `nil` to hide the row.
    public init(
        state: SubscriptionState,
        planName: String,
        isRestoring: Bool = false,
        onUpgrade: @escaping () -> Void,
        onManage: @escaping () -> Void = {},
        onRestore: (() -> Void)? = nil
    ) {
        self.state = state
        self.planName = planName
        self.isRestoring = isRestoring
        self.onUpgrade = onUpgrade
        self.onManage = onManage
        self.onRestore = onRestore
    }

    public var body: some View {
        VStack(spacing: 12) {
            StatusCard(title: cardTitle, detail: cardDetail, icon: cardIcon, tint: cardTint)
            if let actionLabel {
                Button(action: primaryAction) {
                    Text(actionLabel).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            if let onRestore {
                Button(action: onRestore) {
                    HStack(spacing: 6) {
                        if isRestoring { ProgressView() }
                        Text("Restore Purchases")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRestoring)
            }
        }
    }

    // MARK: - State → presentation

    private var cardTitle: String {
        state.isActive ? "\(planName) active" : "\(planName)"
    }

    private var cardDetail: String {
        guard state.isActive else { return "Unlock everything with \(planName)." }
        if let renewalDescription = state.renewalDescription { return renewalDescription }
        switch state.source {
        case .storeKit, .web: return "Your subscription is active."
        case .complimentary: return "Complimentary access."
        }
    }

    private var cardIcon: String {
        state.isActive ? "checkmark.seal.fill" : "sparkles"
    }

    private var cardTint: Color { state.isActive ? .green : .accentColor }

    /// The primary button label, or `nil` when no action applies
    /// (complimentary access is managed by the grantor, not the user).
    private var actionLabel: String? {
        if !state.isActive { return "Upgrade to \(planName)" }
        switch state.source {
        case .storeKit: return "Manage Subscription"
        case .web:      return "Manage on the web"
        case .complimentary: return nil
        }
    }

    private func primaryAction() {
        state.isActive ? onManage() : onUpgrade()
    }
}
