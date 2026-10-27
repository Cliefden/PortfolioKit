import SwiftUI

// MARK: - Feature row

/// One benefit line on a paywall: tinted icon, title, optional subtitle.
///
/// ```swift
/// PaywallFeatureRow(icon: "infinity", title: "Unlimited locations",
///                   subtitle: "Save every spot you fish.")
/// ```
public struct PaywallFeatureRow: View {
    @Environment(\.portfolioSettingsTheme) private var theme
    private let icon: String
    private let title: Text
    private let subtitle: Text?

    public init(icon: String, title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil) {
        self.init(icon: icon, title: Text(title), subtitle: subtitle.map { Text($0) })
    }

    /// Verbatim variant for runtime strings.
    @_disfavoredOverload
    public init<S: StringProtocol>(icon: String, title: S, subtitle: String? = nil) {
        self.init(icon: icon, title: Text(verbatim: String(title)), subtitle: subtitle.map { Text(verbatim: $0) })
    }

    init(icon: String, title: Text, subtitle: Text?) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.system(.body, design: theme.titleDesign).weight(.semibold))
                    .foregroundStyle(theme.value)
                if let subtitle {
                    subtitle.font(.subheadline).foregroundStyle(theme.label)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Product row

/// What a ``PaywallProductRow`` shows — plain values, so PortfolioKit needs no
/// store dependency. Build it from StoreKit with
/// ``PaywallProductDisplay/init(product:isEligibleForIntroOffer:badge:locale:)``,
/// or by hand (screenshot rigs, web-priced plans).
public struct PaywallProductDisplay: Identifiable, Sendable {
    public var id: String
    /// Product name, e.g. `"Annual"` (StoreKit's `displayName` is already localized).
    public var title: String
    /// Display price, e.g. `"$34.99"`.
    public var price: String
    /// Caption under the price, e.g. `"per year"`.
    public var periodText: String?
    /// Secondary line, e.g. `"≈ $2.92 a month"` or `"1 week free, then $3.99/month"`.
    public var detail: String?
    /// Small highlighted capsule, e.g. "Best value".
    public var badge: LocalizedStringResource?

    public init(
        id: String,
        title: String,
        price: String,
        periodText: String? = nil,
        detail: String? = nil,
        badge: LocalizedStringResource? = nil
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.periodText = periodText
        self.detail = detail
        self.badge = badge
    }
}

/// A selectable plan card for a paywall's product list (Contrarian
/// `productRow`, Stokked `ProductRow`): title + optional badge and detail on the
/// left, price + period on the right, a selection mark, and a tint-stroked
/// surface when selected.
///
/// ```swift
/// ForEach(store.products) { product in
///     PaywallProductRow(
///         PaywallProductDisplay(product: product, isEligibleForIntroOffer: store.isEligible,
///                               badge: product.id == annualID ? "Best value" : nil),
///         isSelected: selected == product.id
///     ) { selected = product.id }
/// }
/// ```
public struct PaywallProductRow: View {
    @Environment(\.portfolioSettingsTheme) private var theme
    private let product: PaywallProductDisplay
    private let isSelected: Bool
    private let action: () -> Void

    public init(_ product: PaywallProductDisplay, isSelected: Bool, action: @escaping () -> Void) {
        self.product = product
        self.isSelected = isSelected
        self.action = action
    }

    /// Field-by-field convenience.
    public init(
        title: String,
        price: String,
        periodText: String? = nil,
        detail: String? = nil,
        badge: LocalizedStringResource? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.init(
            PaywallProductDisplay(id: title, title: title, price: price, periodText: periodText, detail: detail, badge: badge),
            isSelected: isSelected,
            action: action
        )
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(verbatim: product.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.value)
                        if let badge = product.badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.tint.opacity(0.15)))
                                .foregroundStyle(.tint)
                        }
                    }
                    if let detail = product.detail {
                        Text(verbatim: detail)
                            .font(.caption)
                            .foregroundStyle(theme.label)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: product.price)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(theme.value))
                    if let periodText = product.periodText {
                        Text(verbatim: periodText)
                            .font(.caption)
                            .foregroundStyle(theme.label)
                    }
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(theme.line))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(theme.line), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Legal footer

/// The App Store–required paywall footer (guideline 3.1.2): Restore Purchases,
/// Terms of Use (EULA) + Privacy Policy links, and the auto-renewal disclosure.
/// Missing EULA/terms links got Contrarian 1.1 rejected under 3.1.2(c).
///
/// ```swift
/// PaywallLegalFooter(legal: .init(privacyPolicy: privacyURL), isRestoring: store.isRestoring) {
///     Task { await store.restore() }
/// }
/// ```
public struct PaywallLegalFooter: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.portfolioSettingsTheme) private var theme
    private let legal: LegalLinks
    private let isRestoring: Bool
    private let showsRenewalNotice: Bool
    private let onRestore: (() -> Void)?

    /// - Parameters:
    ///   - legal: Terms (defaults to Apple's EULA) + Privacy Policy URLs.
    ///   - isRestoring: spinner + disabled Restore while true.
    ///   - showsRenewalNotice: the auto-renewal disclosure; turn off for
    ///     paywalls that only sell non-renewing products.
    ///   - onRestore: restore purchases; `nil` hides the button.
    public init(
        legal: LegalLinks,
        isRestoring: Bool = false,
        showsRenewalNotice: Bool = true,
        onRestore: (() -> Void)?
    ) {
        self.legal = legal
        self.isRestoring = isRestoring
        self.showsRenewalNotice = showsRenewalNotice
        self.onRestore = onRestore
    }

    public var body: some View {
        VStack(spacing: 10) {
            if let onRestore {
                Button(action: onRestore) {
                    HStack(spacing: 6) {
                        if isRestoring { ProgressView() }
                        Text(LocalizedStringResource.portfolioKit("Restore Purchases"))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isRestoring)
            }
            HStack(spacing: 8) {
                link(.portfolioKit("Terms of Use"), url: legal.termsOfUse)
                Text(verbatim: "·").accessibilityHidden(true)
                link(.portfolioKit("Privacy Policy"), url: legal.privacyPolicy)
            }
            .font(.footnote)
            if showsRenewalNotice {
                Text(LocalizedStringResource.portfolioKit("Payment is charged to your Apple Account at confirmation of purchase. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel it in your App Store account settings."))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(theme.label)
        .frame(maxWidth: .infinity)
    }

    private func link(_ title: LocalizedStringResource, url: URL) -> some View {
        Button { openURL(url) } label: { Text(title).underline() }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isLink)
    }
}

#if canImport(StoreKit)
import StoreKit

public extension PaywallProductDisplay {
    /// Build the row's values from a StoreKit 2 product: name, display price,
    /// "per month"-style period caption, and a detail line — the free-trial
    /// text when the user is eligible for one, else the monthly equivalent for
    /// multi-month plans.
    init(
        product: Product,
        isEligibleForIntroOffer: Bool = false,
        badge: LocalizedStringResource? = nil,
        locale: Locale = .current
    ) {
        var periodText: String?
        var detail: String?
        if let subscription = product.subscription {
            let period = SubscriptionPeriod(subscription.subscriptionPeriod)
            periodText = SubscriptionPeriodText.perPeriod(period, locale: locale)
            if isEligibleForIntroOffer,
               let offer = subscription.introductoryOffer,
               offer.paymentMode == .freeTrial {
                detail = SubscriptionPeriodText.freeTrial(
                    SubscriptionPeriod(offer.period), then: product.displayPrice, per: period, locale: locale
                )
            } else {
                detail = SubscriptionPeriodText.perMonthNote(
                    price: product.price, period: period, format: product.priceFormatStyle, locale: locale
                )
            }
        }
        self.init(
            id: product.id, title: product.displayName, price: product.displayPrice,
            periodText: periodText, detail: detail, badge: badge
        )
    }
}
#endif
