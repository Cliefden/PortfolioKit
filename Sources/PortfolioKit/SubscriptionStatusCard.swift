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

/// Pure state → presentation mapping for ``SubscriptionStatusCard`` — the
/// compliance-relevant decisions (which action, whether Restore makes sense),
/// kept separate from the view so they can be unit-tested.
struct SubscriptionPresentation {
    enum Action: Equatable {
        /// Inactive → present the paywall.
        case upgrade
        /// Active StoreKit sub → native `.manageSubscriptionsSheet`.
        case manageInApp
        /// Active web/Stripe sub → billing portal.
        case manageOnWeb
    }

    let state: SubscriptionState
    let planName: String

    var title: LocalizedStringResource {
        state.isActive
            ? .portfolioKit("\(planName) active", comment: "Subscription card title; %@ is the plan name, e.g. Plus")
            : .portfolioKit("\(planName)", comment: "Subscription card title when inactive; the plan name")
    }

    var detail: LocalizedStringResource {
        guard state.isActive else {
            return .portfolioKit("Unlock everything with \(planName).", comment: "%@ is the plan name")
        }
        if let renewalDescription = state.renewalDescription {
            return .portfolioKit("\(renewalDescription)", comment: "App-supplied renewal text, shown as is")
        }
        switch state.source {
        case .storeKit, .web: return .portfolioKit("Your subscription is active.")
        case .complimentary: return .portfolioKit("Complimentary access.")
        }
    }

    var icon: String { state.isActive ? "checkmark.seal.fill" : "sparkles" }

    /// The primary action, or `nil` when none applies (complimentary access is
    /// managed by the grantor, not the user).
    var action: Action? {
        guard state.isActive else { return .upgrade }
        switch state.source {
        case .storeKit: return .manageInApp
        case .web: return .manageOnWeb
        case .complimentary: return nil
        }
    }

    var actionLabel: LocalizedStringResource? {
        switch action {
        case .upgrade: return .portfolioKit("Upgrade to \(planName)", comment: "%@ is the plan name")
        case .manageInApp: return .portfolioKit("Manage Subscription")
        case .manageOnWeb: return .portfolioKit("Manage on the web")
        case nil: return nil
        }
    }

    /// StoreKit "Restore Purchases" only makes sense when there is nothing
    /// active, or when the active entitlement came from StoreKit. For web or
    /// complimentary access it is meaningless and confusing, so it is hidden.
    var showsRestore: Bool {
        !state.isActive || state.source == .storeKit
    }
}

/// A subscription status block: a tinted `StatusCard` plus the *compliant* action
/// for the current state — Upgrade when inactive, source-appropriate Manage when
/// active, and Restore (hidden for active web/complimentary access, where StoreKit
/// restore doesn't apply). The app supplies the closures; this view only decides
/// which affordance is correct for the state/source. `planName` is a brand name
/// and is not translated; the surrounding copy is localized by PortfolioKit.
public struct SubscriptionStatusCard: View {
    private let presentation: SubscriptionPresentation
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
    ///   - onRestore: restore purchases. Pass `nil` to hide the row. Also hidden
    ///     automatically for active `.web` / `.complimentary` access.
    public init(
        state: SubscriptionState,
        planName: String,
        isRestoring: Bool = false,
        onUpgrade: @escaping () -> Void,
        onManage: @escaping () -> Void = {},
        onRestore: (() -> Void)? = nil
    ) {
        self.presentation = SubscriptionPresentation(state: state, planName: planName)
        self.isRestoring = isRestoring
        self.onUpgrade = onUpgrade
        self.onManage = onManage
        self.onRestore = onRestore
    }

    public var body: some View {
        VStack(spacing: 12) {
            StatusCard(
                title: Text(presentation.title),
                detail: Text(presentation.detail),
                icon: presentation.icon,
                tint: presentation.state.isActive ? .green : .accentColor
            )
            if let actionLabel = presentation.actionLabel {
                Button(action: primaryAction) {
                    Text(actionLabel).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            if let onRestore, presentation.showsRestore {
                Button(action: onRestore) {
                    HStack(spacing: 6) {
                        if isRestoring { ProgressView() }
                        Text(LocalizedStringResource.portfolioKit("Restore Purchases"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRestoring)
            }
        }
    }

    private func primaryAction() {
        presentation.action == .upgrade ? onUpgrade() : onManage()
    }
}
