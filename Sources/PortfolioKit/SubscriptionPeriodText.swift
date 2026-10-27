import Foundation

/// A subscription period as plain data (`value` × `unit`), so paywall copy can
/// be built and tested without StoreKit. Bridge from StoreKit with
/// `SubscriptionPeriod(product.subscription!.subscriptionPeriod)`.
public struct SubscriptionPeriod: Sendable, Hashable {
    public enum Unit: Sendable, Hashable, CaseIterable {
        case day, week, month, year
    }

    public var value: Int
    public var unit: Unit

    public init(value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }

    public static let weekly = SubscriptionPeriod(value: 1, unit: .week)
    public static let monthly = SubscriptionPeriod(value: 1, unit: .month)
    public static let yearly = SubscriptionPeriod(value: 1, unit: .year)

    /// Whole months in the period (`nil` for day/week periods).
    public var months: Int? {
        switch unit {
        case .month: value
        case .year: value * 12
        case .day, .week: nil
        }
    }
}

/// Localized paywall copy for subscription periods, prices and trials —
/// Stokked `AICreditsView.periodDescription` / `freeTrialText` and Contrarian
/// `PaywallView.perMonthNote`, translated via PortfolioKit's catalog.
///
/// ```swift
/// SubscriptionPeriodText.unit(.monthly)                                  // "month"
/// SubscriptionPeriodText.length(.init(value: 3, unit: .day))             // "3 days"
/// SubscriptionPeriodText.pricePerPeriod("$3.99", period: .monthly)       // "$3.99/month"
/// SubscriptionPeriodText.freeTrial(.weekly, then: "$3.99", per: .monthly) // "1 week free, then $3.99/month"
/// SubscriptionPeriodText.perMonthNote(price: 34.99, period: .yearly,
///                                     format: product.priceFormatStyle)   // "≈ $2.92 a month"
/// ```
///
/// Every function takes a `locale` (default: the user's) so it can be tested;
/// the language comes from the package catalog for that locale.
public enum SubscriptionPeriodText {
    /// The period as a unit for "per …" / "…/…" copy: `"month"` for one,
    /// `"3 months"` otherwise.
    public static func unit(_ period: SubscriptionPeriod, locale: Locale = .current) -> String {
        guard period.value == 1 else { return length(period, locale: locale) }
        let resource: LocalizedStringResource = switch period.unit {
        case .day: .portfolioKit("day", comment: "Subscription period unit, as in $1/day")
        case .week: .portfolioKit("week", comment: "Subscription period unit, as in $1/week")
        case .month: .portfolioKit("month", comment: "Subscription period unit, as in $1/month")
        case .year: .portfolioKit("year", comment: "Subscription period unit, as in $1/year")
        }
        return resolve(resource, locale)
    }

    /// The period with its count, pluralized: `"1 week"`, `"3 days"`.
    public static func length(_ period: SubscriptionPeriod, locale: Locale = .current) -> String {
        let n = period.value
        let resource: LocalizedStringResource = switch period.unit {
        case .day: .portfolioKit("\(n) days", comment: "Period length; plural")
        case .week: .portfolioKit("\(n) weeks", comment: "Period length; plural")
        case .month: .portfolioKit("\(n) months", comment: "Period length; plural")
        case .year: .portfolioKit("\(n) years", comment: "Period length; plural")
        }
        return resolve(resource, locale)
    }

    /// `"per month"`, `"per 3 months"` — the caption under a price.
    public static func perPeriod(_ period: SubscriptionPeriod, locale: Locale = .current) -> String {
        let unit = unit(period, locale: locale)
        return resolve(.portfolioKit("per \(unit)", comment: "Under a price; %@ is a period unit, e.g. month"), locale)
    }

    /// `"$3.99/month"`. `price` is the store's display price, shown as is.
    /// (The slash form reads the same in every shipped language, so only the
    /// unit is translated.)
    public static func pricePerPeriod(_ price: String, period: SubscriptionPeriod, locale: Locale = .current) -> String {
        "\(price)/\(unit(period, locale: locale))"
    }

    /// `"1 week free, then $3.99/month"` for a free-trial introductory offer.
    /// Only show it to users eligible for the intro offer.
    public static func freeTrial(_ trial: SubscriptionPeriod, then price: String, per period: SubscriptionPeriod, locale: Locale = .current) -> String {
        let length = length(trial, locale: locale)
        let recurring = pricePerPeriod(price, period: period, locale: locale)
        return resolve(.portfolioKit("\(length) free, then \(recurring)", comment: "Free trial; 1: trial length, 2: price per period"), locale)
    }

    /// The equivalent monthly price for a multi-month period (`nil` for monthly
    /// or shorter periods).
    public static func perMonthPrice(price: Decimal, period: SubscriptionPeriod) -> Decimal? {
        guard let months = period.months, months > 1 else { return nil }
        return price / Decimal(months)
    }

    /// `"≈ $2.92 a month"` for annual (or other multi-month) plans, formatted
    /// with the product's own currency style (`Product.priceFormatStyle`).
    public static func perMonthNote(
        price: Decimal,
        period: SubscriptionPeriod,
        format: Decimal.FormatStyle.Currency,
        locale: Locale = .current
    ) -> String? {
        guard let perMonth = perMonthPrice(price: price, period: period) else { return nil }
        let formatted = perMonth.formatted(format)
        return resolve(.portfolioKit("≈ \(formatted) a month", comment: "Monthly equivalent of an annual price"), locale)
    }

    /// ``perMonthNote(price:period:format:locale:)`` from an ISO currency code.
    public static func perMonthNote(price: Decimal, period: SubscriptionPeriod, currencyCode: String, locale: Locale = .current) -> String? {
        perMonthNote(price: price, period: period, format: .currency(code: currencyCode).locale(locale), locale: locale)
    }

    private static func resolve(_ resource: LocalizedStringResource, _ locale: Locale) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }
}

#if canImport(StoreKit)
import StoreKit

public extension SubscriptionPeriod {
    /// Bridge from StoreKit 2.
    init(_ period: Product.SubscriptionPeriod) {
        let unit: Unit = switch period.unit {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        @unknown default: .month
        }
        self.init(value: period.value, unit: unit)
    }
}
#endif
