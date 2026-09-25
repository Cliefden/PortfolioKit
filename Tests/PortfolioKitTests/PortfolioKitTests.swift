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
