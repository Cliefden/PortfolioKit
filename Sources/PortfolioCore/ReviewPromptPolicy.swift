import Foundation

/// Decides *when* it is reasonable to ask for an App Store review. Ported from
/// Otta's `ReviewPrompt` (and its tests), generalized for the portfolio.
///
/// The ask itself stays in the view layer — SwiftUI's `requestReview` action
/// needs a scene — so this type only owns the policy: count genuinely positive
/// moments (a saved entry, a successful export) and allow a prompt once enough
/// have accumulated, **at most once per app version** and never twice inside
/// `minimumDaysBetweenPrompts`.
///
/// Never call it on launch, on first run, or near the paywall: iOS silently
/// drops requests beyond three a year, so the few we get should land right
/// after something went *right* for the user.
///
/// ```swift
/// @Environment(\.requestReview) private var requestReview
/// let reviews = ReviewPromptPolicy()
///
/// func didSaveEntry(outcome: Outcome) {
///     if reviews.record("entrySaved", promptAllowed: outcome.isGoodMoment) {
///         requestReview()
///     }
/// }
/// ```
public struct ReviewPromptPolicy {
    /// Milestones needed before an ask (counted across all milestone keys).
    public var milestonesRequired: Int
    /// Never ask twice inside this many days, even across app versions.
    public var minimumDaysBetweenPrompts: Int

    private let defaults: UserDefaults
    private let now: () -> Date
    private let currentVersion: () -> String?
    private let keys: Keys

    struct Keys {
        let milestoneCount: String
        let lastPromptedVersion: String
        let lastPromptedDate: String

        init(prefix: String) {
            // Same layout as Otta's keys ("review.milestoneCount.v1", …) so it
            // can adopt this without resetting users' progress.
            milestoneCount = "\(prefix).milestoneCount.v1"
            lastPromptedVersion = "\(prefix).lastPromptedVersion.v1"
            lastPromptedDate = "\(prefix).lastPromptedDate.v1"
        }
    }

    /// - Parameters:
    ///   - milestonesRequired: positive moments before the first ask (Otta: 3).
    ///   - minimumDaysBetweenPrompts: cool-down across versions (Otta: 120).
    ///   - keyPrefix: `UserDefaults` key prefix; `"review"` matches Otta.
    ///   - defaults: injectable for tests.
    ///   - now: injectable clock.
    ///   - version: the marketing version; defaults to the main bundle's
    ///     `CFBundleShortVersionString`. Returning `nil` never prompts.
    public init(
        milestonesRequired: Int = 3,
        minimumDaysBetweenPrompts: Int = 120,
        keyPrefix: String = "review",
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        version: @escaping () -> String? = { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String }
    ) {
        self.milestonesRequired = milestonesRequired
        self.minimumDaysBetweenPrompts = minimumDaysBetweenPrompts
        self.defaults = defaults
        self.now = now
        self.currentVersion = version
        self.keys = Keys(prefix: keyPrefix)
    }

    /// Record a positive moment and report whether now is a good time to ask.
    ///
    /// Returns `true` at most once per version (and per cool-down), and marks the
    /// prompt as spent when it does — so present the review request whenever
    /// this returns `true`.
    ///
    /// Pass `promptAllowed: false` when the action still counts as engagement but
    /// the moment is a bad one to ask in (e.g. logging a miss). The milestone is
    /// counted; the ask waits for the next good moment.
    ///
    /// - Parameter milestone: a stable key for the moment (`"entrySaved"`); kept
    ///   for the caller's analytics — every milestone counts toward the same total.
    @discardableResult
    public func record(_ milestone: String, promptAllowed: Bool = true) -> Bool {
        let count = defaults.integer(forKey: keys.milestoneCount) + 1
        defaults.set(count, forKey: keys.milestoneCount)

        guard promptAllowed, count >= milestonesRequired, let version = currentVersion() else {
            return false
        }
        if defaults.string(forKey: keys.lastPromptedVersion) == version {
            return false
        }
        let date = now()
        if let last = defaults.object(forKey: keys.lastPromptedDate) as? Date {
            let days = date.timeIntervalSince(last) / 86_400
            guard days >= Double(minimumDaysBetweenPrompts) else { return false }
        }

        defaults.set(version, forKey: keys.lastPromptedVersion)
        defaults.set(date, forKey: keys.lastPromptedDate)
        defaults.set(0, forKey: keys.milestoneCount)
        return true
    }

    /// `RawRepresentable` convenience, e.g. an app's `enum Milestone: String`.
    @discardableResult
    public func record<M: RawRepresentable>(_ milestone: M, promptAllowed: Bool = true) -> Bool
    where M.RawValue == String {
        record(milestone.rawValue, promptAllowed: promptAllowed)
    }

    /// Milestones counted since the last prompt.
    public var milestoneCount: Int { defaults.integer(forKey: keys.milestoneCount) }

    /// When the policy last allowed a prompt.
    public var lastPromptDate: Date? { defaults.object(forKey: keys.lastPromptedDate) as? Date }

    /// Forget all state (e.g. on account deletion or in tests).
    public func reset() {
        defaults.removeObject(forKey: keys.milestoneCount)
        defaults.removeObject(forKey: keys.lastPromptedVersion)
        defaults.removeObject(forKey: keys.lastPromptedDate)
    }
}
