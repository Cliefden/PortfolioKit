# PortfolioKit

Shared, **backend-free** SwiftUI components + small helpers for the Apps-AppStore
family. Pure SwiftUI/Foundation, no external dependencies, no networking — the app
always supplies the side-effecting work (deletion, subscription management) via
closures. Part of the portfolio standard (`_standard/PORTFOLIO_STANDARD.md` §3/§5);
patterns are distilled in `SETTINGS_BEST_PRACTICES.md`.

> **Layout note.** These components draw their own rounded, stroked surfaces and
> are designed for a `ScrollView { VStack { … } }` settings screen (Contrarian
> style), **not** inside a `Form`/`List` (where the surfaces would double-inset).

## What's in it

Building blocks (genericized from Contrarian, themeable via `PortfolioSettingsTheme`):

- **`SettingsSection`**, **`InfoRow`**, **`StatusCard`** — section header, key/value
  row, tinted status card.
- **`LegalLinks`** + **`LegalLinkRow`** — privacy/terms/support URLs (Apple EULA
  default) and a tappable external-link row with the `arrow.up.right` convention.
- **`Bundle.versionAndBuild`** / `appVersion` / `buildNumber` — the About-row version
  string, previously duplicated across ~8 apps.

Higher-level, ready-to-drop pieces:

- **`AboutSection(legal:credit:)`** — version row + Support/Privacy/Terms links.
- **`SubscriptionStatusCard(...)`** — **source-aware** subscription block. Renders
  Upgrade when inactive, and the *compliant* Manage affordance when active
  (`.storeKit` → native manage sheet, `.web` → billing portal, `.complimentary` →
  no action), plus an optional Restore. Distilled from Contrarian + Nassau.
- **`DeleteAccountView(config:onDelete:)`** — the gold-standard destructive flow
  (App Store guideline 5.1.1(v)): typed confirmation phrase, countdown gate,
  App Store-subscription warning, final confirmation dialog, then the app-supplied
  async `onDelete`. Distilled from Nassau + Contrarian.
- **`PortfolioSettings`** — the reference **settings-store pattern**: an
  `@Observable` singleton whose properties persist to `UserDefaults` via `didSet`,
  injected through `@Environment` (from Lunker's `UnitSettings`). Ships
  `appearance` + `hapticsEnabled` — use directly or copy for app-specific stores.
- **`AppearancePicker`** + **`ColorSchemePreference`** — segmented light/dark/system
  picker feeding `.preferredColorScheme`.

## Use

Theme it once near the root of your settings screen to match your brand:

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
ScrollView {
    VStack(spacing: 28) {
        SubscriptionStatusCard(
            state: SubscriptionState(isActive: isPlus, source: .storeKit,
                                     renewalDescription: "Renews 5 Jan 2027"),
            planName: "Plus",
            onUpgrade: { showPaywall = true },
            onManage:  { showManageSheet = true },      // .storeKit → native sheet
            onRestore: { Task { await store.restore() } }
        )

        AppearancePicker(selection: $settings.appearance)

        AboutSection(legal: LegalLinks(
            privacyPolicy: URL(string: "https://crawik.com/app/privacy")!,
            support:       URL(string: "https://crawik.com/app/support")!
        ))
    }
    .padding()
}
```

Push the delete flow from the Account section — the app provides the deletion work:

```swift
NavigationLink("Delete Account") {
    DeleteAccountView(
        config: .init(deletedItems: ["Profile", "Saved rounds", "Photos"]),
        onDelete: { try await auth.deleteAccount() }
    )
}
```

Wire the settings store at the app entry point:

```swift
@main struct MyApp: App {
    @State private var settings = PortfolioSettings.shared
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
```

## Adoption (per app, one dimension per commit)

1. **About** → swap hand-rolled version/legal rows for `AboutSection`.
2. **Delete account** → replace the bespoke view with the shared `DeleteAccountView`
   (Contrarian/Nassau already match its shape; others gain the flow for free).
3. **Subscription** → route paywall/manage/restore through `SubscriptionStatusCard`
   so the `.storeKit` vs `.web` compliance split is uniform.
4. **Appearance/haptics** → adopt `PortfolioSettings`.

## Versioning

Tagged releases; apps depend on it by URL + version (CI-safe — resolvable in Xcode
Cloud, unlike a sibling local path). Use `Add Local…` only for local development.

## Build / test

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

(The plain Command Line Tools can't link the SPM manifest; point at a full Xcode.)
