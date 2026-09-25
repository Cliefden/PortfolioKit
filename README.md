# PortfolioKit

Shared, backend-free SwiftUI components + small helpers for the Apps-AppStore family.
Pure SwiftUI/Foundation, no external dependencies. Part of the portfolio standard
(`_standard/PORTFOLIO_STANDARD.md` §3/§5).

## What's in it

- **`Bundle.versionAndBuild`** / `appVersion` / `buildNumber` — the About-row version
  string, previously duplicated across ~8 apps.
- **`LegalLinks`** + **`LegalLinkRow`** — privacy/terms/support URLs (Apple EULA default)
  and a tappable external-link row with the `arrow.up.right` convention.
- **`SettingsSection`**, **`InfoRow`**, **`StatusCard`** — the settings building blocks,
  genericized from Contrarian. Themeable via `PortfolioSettingsTheme` / `.portfolioSettingsTheme(_:)`.

## Use

Add the package (URL + version) and `import PortfolioKit`. Theme it once near the root of
your settings screen to match your brand:

```swift
SettingsView()
    .portfolioSettingsTheme(
        PortfolioSettingsTheme(
            label: .contriaMuted, value: .contriaFg,
            panel: .contriaPanel, line: .contriaLine, titleDesign: .serif
        )
    )
```

Then compose:

```swift
SettingsSection("About") {
    LegalLinkRow("Privacy policy", url: legal.privacyPolicy)
    InfoRow("Version", Bundle.main.versionAndBuild)
}
```

## Versioning

Tagged releases; apps depend on it by URL + version (CI-safe — resolvable in Xcode Cloud,
unlike a sibling local path).
