import Foundation

/// Localized date/time helpers with cached formatters — the near-identical
/// `DateFormattingUtils` in Lunker, Sextant and Equinox, plus Celiador's
/// `RelativeTime.short`. Formatters are created once per
/// (kind, template, time zone, locale) and reused; formatting runs under a lock,
/// so every function is safe from any thread.
///
/// ```swift
/// PortfolioDateFormat.time(sunrise, timeZone: location.timeZone)   // "06:42" / "6:42 AM"
/// PortfolioDateFormat.shortDate(date)                              // "Jun 5" / "5 juni"
/// PortfolioDateFormat.duration(daylight)                           // "14h 32m"
/// PortfolioDateFormat.daysBetween(from: .now, to: solstice)        // 37
/// PortfolioDateFormat.relativeShort(message.createdAt)             // "now" / "4m" / "3h" / "2d" / "Mar 5"
/// ```
public enum PortfolioDateFormat {
    /// Shown by ``time(_:timeZone:locale:)`` for a `nil` date (polar day/night).
    public static let missingTime = "--:--"
    /// Shown by ``duration(_:locale:)`` for a `nil` interval.
    public static let missingDuration = "--"

    // MARK: Absolute

    /// Short time honouring the user's 12/24-hour preference.
    public static func time(_ date: Date?, timeZone: TimeZone = .current, locale: Locale = .autoupdatingCurrent) -> String {
        guard let date else { return missingTime }
        return string(from: date, key: "time", timeZone: timeZone, locale: locale) {
            $0.dateStyle = .none
            $0.timeStyle = .short
        }
    }

    /// Localized month + day ("Jun 5", "5 juni", "6月5日").
    public static func shortDate(_ date: Date, timeZone: TimeZone = .current, locale: Locale = .autoupdatingCurrent) -> String {
        format(date, template: "MMMd", timeZone: timeZone, locale: locale)
    }

    /// Localized month + day + year ("Jun 5, 2026").
    public static func shortDateWithYear(_ date: Date, timeZone: TimeZone = .current, locale: Locale = .autoupdatingCurrent) -> String {
        format(date, template: "MMMdyyyy", timeZone: timeZone, locale: locale)
    }

    /// Localized month + year ("June 2026").
    public static func monthYear(_ date: Date, timeZone: TimeZone = .current, locale: Locale = .autoupdatingCurrent) -> String {
        format(date, template: "MMMMyyyy", timeZone: timeZone, locale: locale)
    }

    /// Format with a localized skeleton template (`setLocalizedDateFormatFromTemplate`).
    public static func format(_ date: Date, template: String, timeZone: TimeZone = .current, locale: Locale = .autoupdatingCurrent) -> String {
        string(from: date, key: "template:" + template, timeZone: timeZone, locale: locale) {
            $0.setLocalizedDateFormatFromTemplate(template)
        }
    }

    // MARK: Durations & day counts

    /// Hours + minutes, abbreviated and localized ("14h 32m" in English). Both
    /// units are always shown, matching the apps' previous `"\(h)h \(m)m"`.
    public static func duration(_ interval: TimeInterval?, locale: Locale = .autoupdatingCurrent) -> String {
        guard let interval, interval.isFinite else { return missingDuration }
        let totalMinutes = Int(interval) / 60
        var components = DateComponents()
        components.hour = totalMinutes / 60
        components.minute = totalMinutes % 60
        return cache.withValue(key: "duration|\(locale.identifier)", make: {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            formatter.zeroFormattingBehavior = .pad
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = locale
            formatter.calendar = calendar
            return formatter as AnyObject
        }) { ($0 as! DateComponentsFormatter).string(from: components) } ?? missingDuration
    }

    /// Whole calendar days from `from` to `to`, counted in `timeZone` (pass the
    /// location's zone when the dates are location-local). Negative when `to`
    /// is earlier.
    public static func daysBetween(from: Date, to: Date, timeZone: TimeZone = .current) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    // MARK: Relative

    /// Compact relative time for lists and feeds: "now" (< 45 s), then minutes,
    /// hours and days in the locale's abbreviated units ("4m", "3h", "2d" in
    /// English), and the short date ("Mar 5") from a week on. Future dates
    /// read as "now".
    public static func relativeShort(_ date: Date, now: Date = Date(), timeZone: TimeZone = .current, locale: Locale = .autoupdatingCurrent) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 45 {
            return cache.withValue(key: "now|\(locale.identifier)", make: {
                let formatter = RelativeDateTimeFormatter()
                formatter.dateTimeStyle = .named
                formatter.locale = locale
                return formatter as AnyObject
            }) { ($0 as! RelativeDateTimeFormatter).localizedString(fromTimeInterval: 0) }
        }
        let unit: NSCalendar.Unit
        let value: Int
        switch seconds {
        case ..<3_600: (unit, value) = (.minute, max(1, Int(seconds / 60)))
        case ..<86_400: (unit, value) = (.hour, Int(seconds / 3_600))
        case ..<604_800: (unit, value) = (.day, Int(seconds / 86_400))
        default: return shortDate(date, timeZone: timeZone, locale: locale)
        }
        var components = DateComponents()
        switch unit {
        case .minute: components.minute = value
        case .hour: components.hour = value
        default: components.day = value
        }
        return cache.withValue(key: "relative|\(unit.rawValue)|\(locale.identifier)", make: {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = unit
            formatter.unitsStyle = .abbreviated
            formatter.maximumUnitCount = 1
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = locale
            formatter.calendar = calendar
            return formatter as AnyObject
        }) { ($0 as! DateComponentsFormatter).string(from: components) } ?? ""
    }

    /// ``relativeShort(_:now:timeZone:locale:)`` for an ISO 8601 timestamp (with
    /// or without fractional seconds); `""` when it doesn't parse.
    public static func relativeShort(iso: String, now: Date = Date(), timeZone: TimeZone = .current, locale: Locale = .autoupdatingCurrent) -> String {
        guard let date = parseISO8601(iso) else { return "" }
        return relativeShort(date, now: now, timeZone: timeZone, locale: locale)
    }

    /// Parse an ISO 8601 internet date-time, with or without fractional seconds.
    public static func parseISO8601(_ string: String) -> Date? {
        cache.withValue(key: "iso", make: {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter as AnyObject
        }) { ($0 as! ISO8601DateFormatter).date(from: string) }
            ?? cache.withValue(key: "iso-plain", make: { ISO8601DateFormatter() as AnyObject }) {
                ($0 as! ISO8601DateFormatter).date(from: string)
            }
    }

    // MARK: Cache

    private static let cache = FormatterCache()

    /// Format `date` with the cached `DateFormatter` for (key, zone, locale).
    private static func string(
        from date: Date, key: String, timeZone: TimeZone, locale: Locale, configure: (DateFormatter) -> Void
    ) -> String {
        cache.withValue(key: "\(key)|\(timeZone.identifier)|\(locale.identifier)", make: {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            configure(formatter)
            return formatter
        }) { ($0 as! DateFormatter).string(from: date) }
    }
}

/// Lock-protected formatter storage. Formatters aren't `Sendable`; they are only
/// ever touched inside `withValue`, under the lock.
private final class FormatterCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: AnyObject] = [:]

    func withValue<R>(key: String, make: () -> AnyObject, _ body: (AnyObject) -> R) -> R {
        lock.withLock {
            let value: AnyObject
            if let existing = storage[key] {
                value = existing
            } else {
                value = make()
                storage[key] = value
            }
            return body(value)
        }
    }
}
