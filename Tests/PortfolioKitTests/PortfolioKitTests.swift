import Testing
import SwiftUI
@testable import PortfolioKit

@Test func legalLinksDefaultsToAppleEULA() {
    let links = LegalLinks(privacyPolicy: URL(string: "https://example.com/privacy")!)
    #expect(links.termsOfUse == LegalLinks.appleStandardEULA)
    #expect(links.support == nil)
}

@Test func themeHasSaneDefaults() {
    let theme = PortfolioSettingsTheme.default
    #expect(theme.cornerRadius == 12)
    #expect(theme.titleDesign == .default)
}

@Test func colorSchemePreferenceMapsToScheme() {
    #expect(ColorSchemePreference.system.colorScheme == nil)
    #expect(ColorSchemePreference.light.colorScheme == .light)
    #expect(ColorSchemePreference.dark.colorScheme == .dark)
}

@Test func subscriptionInactiveDefault() {
    let s = SubscriptionState.inactive
    #expect(s.isActive == false)
}

@MainActor
@Test func settingsPersistAndReload() {
    let suite = "portfoliokit.tests.\(#function)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)

    let settings = PortfolioSettings(defaults: defaults)
    #expect(settings.appearance == .system)   // unset → follow system
    #expect(settings.hapticsEnabled == true)  // unset → on

    settings.appearance = .dark
    settings.hapticsEnabled = false

    // A fresh store reading the same defaults sees the persisted values.
    let reloaded = PortfolioSettings(defaults: defaults)
    #expect(reloaded.appearance == .dark)
    #expect(reloaded.hapticsEnabled == false)

    defaults.removePersistentDomain(forName: suite)
}

// MARK: - Localization (Bundle.module string catalog)

private func resolve(_ resource: LocalizedStringResource, _ locale: String) -> String {
    var r = resource
    r.locale = Locale(identifier: locale)
    return String(localized: r)
}

@Test func packageStringsResolveFromModuleBundle() {
    #expect(resolve(.portfolioKit("Privacy Policy"), "en") == "Privacy Policy")
    #expect(resolve(.portfolioKit("Privacy Policy"), "sv") == "Integritetspolicy")
    #expect(resolve(.portfolioKit("Restore Purchases"), "de") == "Käufe wiederherstellen")
}

@Test func interpolatedPackageStringsFormat() {
    #expect(resolve(.portfolioKit("Upgrade to \("Plus")"), "en") == "Upgrade to Plus")
    #expect(resolve(.portfolioKit("Upgrade to \("Plus")"), "sv") == "Uppgradera till Plus")
}

@Test func colorSchemeLabelsAreLocalized() {
    #expect(resolve(ColorSchemePreference.dark.label, "sv") == "Mörkt")
}

// MARK: - SubscriptionPresentation

@Test func inactiveOffersUpgradeAndRestore() {
    let p = SubscriptionPresentation(state: .inactive, planName: "Plus")
    #expect(p.action == .upgrade)
    #expect(p.showsRestore)
    #expect(resolve(p.actionLabel!, "en") == "Upgrade to Plus")
    #expect(resolve(p.detail, "en") == "Unlock everything with Plus.")
}

@Test func storeKitActiveManagesInAppAndKeepsRestore() {
    let p = SubscriptionPresentation(state: .init(isActive: true, source: .storeKit), planName: "Plus")
    #expect(p.action == .manageInApp)
    #expect(p.showsRestore)
    #expect(resolve(p.title, "en") == "Plus active")
    #expect(resolve(p.detail, "en") == "Your subscription is active.")
}

@Test func webActiveManagesOnWebWithoutRestore() {
    let p = SubscriptionPresentation(state: .init(isActive: true, source: .web), planName: "Pro")
    #expect(p.action == .manageOnWeb)
    #expect(!p.showsRestore)
    #expect(resolve(p.actionLabel!, "en") == "Manage on the web")
}

@Test func complimentaryHasNoActionAndNoRestore() {
    let p = SubscriptionPresentation(state: .init(isActive: true, source: .complimentary), planName: "Pro")
    #expect(p.action == nil)
    #expect(p.actionLabel == nil)
    #expect(!p.showsRestore)
    #expect(resolve(p.detail, "en") == "Complimentary access.")
}

@Test func renewalDescriptionOverridesDetail() {
    let p = SubscriptionPresentation(
        state: .init(isActive: true, source: .storeKit, renewalDescription: "Renews 5 Jan 2027"),
        planName: "Plus"
    )
    #expect(resolve(p.detail, "en") == "Renews 5 Jan 2027")
}

// MARK: - DeleteAccountGate

@Test func deleteRequiresExactPhrase() {
    #expect(!DeleteAccountGate(phrase: "DELETE", typed: "delete", remaining: 0, isDeleting: false).canDelete)
    #expect(!DeleteAccountGate(phrase: "DELETE", typed: "DELET", remaining: 0, isDeleting: false).canDelete)
    #expect(DeleteAccountGate(phrase: "DELETE", typed: "DELETE", remaining: 0, isDeleting: false).canDelete)
}

@Test func deleteBlockedDuringCountdownAndWhileDeleting() {
    let counting = DeleteAccountGate(phrase: "DELETE", typed: "DELETE", remaining: 3, isDeleting: false)
    #expect(counting.isCountingDown)
    #expect(!counting.canDelete)
    #expect(!DeleteAccountGate(phrase: "DELETE", typed: "DELETE", remaining: 0, isDeleting: true).canDelete)
}

@Test func countdownOnlyShownOnceThePhraseMatches() {
    // Before the phrase matches the countdown is not running/shown.
    let notYet = DeleteAccountGate(phrase: "DELETE", typed: "DEL", remaining: 5, isDeleting: false)
    #expect(!notYet.isCountingDown)
    #expect(!notYet.canDelete)
}

@Test func deleteConfigDefaultsAreLocalizedFromPackage() {
    let config = DeleteAccountConfig()
    #expect(resolve(config.title, "sv") == "Radera konto")
    #expect(config.confirmationPhrase == "DELETE")
    #expect(config.countdownSeconds == 5)
}
