import Foundation
import Testing
@testable import PortfolioCore

/// Ported from Otta's `ReviewPromptTests`, plus the generalized knobs.
@Suite struct ReviewPromptPolicyTests {
    final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(days: Double) { now = now.addingTimeInterval(days * 86_400) }
    }

    let suite = "portfoliocore.review.\(UUID().uuidString)"
    let defaults: UserDefaults
    let clock = Clock()

    init() {
        defaults = UserDefaults(suiteName: suite)!
    }

    func policy(version: String? = "1.0", required: Int = 3, days: Int = 120, prefix: String = "review") -> ReviewPromptPolicy {
        let clock = clock
        return ReviewPromptPolicy(
            milestonesRequired: required, minimumDaysBetweenPrompts: days, keyPrefix: prefix,
            defaults: defaults, now: { clock.now }, version: { version }
        )
    }

    @Test func promptsOnlyAfterThirdMilestone() {
        let p = policy()
        #expect(!p.record("logSaved"))
        #expect(!p.record("logSaved"))
        #expect(p.record("logSaved"))
    }

    @Test func promptsAtMostOncePerVersion() {
        let p = policy()
        for _ in 0..<3 { p.record("logSaved") }
        clock.advance(days: 200)
        for _ in 0..<10 { #expect(!p.record("calendarExported")) }
    }

    @Test func badMomentCountsButDefersPrompt() {
        let p = policy()
        p.record("logSaved")
        p.record("logSaved")
        #expect(!p.record("logSaved", promptAllowed: false))
        #expect(p.milestoneCount == 3)
        #expect(p.record("logSaved"))
    }

    @Test func newVersionStillWaitsForCooldown() {
        for _ in 0..<3 { policy(version: "1.0").record("m") }
        clock.advance(days: 30)
        let v2 = policy(version: "1.1")
        for _ in 0..<3 { #expect(!v2.record("m")) }
        clock.advance(days: 100)
        #expect(v2.record("m"))
    }

    @Test func countResetsAfterPrompt() {
        let p = policy()
        for _ in 0..<3 { p.record("m") }
        #expect(p.milestoneCount == 0)
        #expect(p.lastPromptDate == clock.now)
    }

    @Test func missingVersionNeverPrompts() {
        let p = policy(version: nil)
        for _ in 0..<5 { #expect(!p.record("m")) }
    }

    @Test func customThresholdAndRawRepresentable() {
        enum Milestone: String { case exported }
        let p = policy(required: 1)
        #expect(p.record(Milestone.exported))
    }

    @Test func keysMatchOttaLayout() {
        let p = policy()
        p.record("m")
        #expect(defaults.integer(forKey: "review.milestoneCount.v1") == 1)
        p.reset()
        #expect(defaults.object(forKey: "review.milestoneCount.v1") == nil)
    }

    @Test func prefixesIsolateState() {
        let a = policy(required: 2, prefix: "a")
        let b = policy(required: 2, prefix: "b")
        a.record("m")
        #expect(!b.record("m"))
        #expect(a.record("m"))
    }
}
