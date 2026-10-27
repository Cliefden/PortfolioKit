# PortfolioKit

Shared, **backend-free** code for the Apps-AppStore family, as two library products
of one package (no external dependencies, no networking — the app always supplies
the side-effecting work via closures):

| Product | What | Imports |
|---|---|---|
| **`PortfolioKit`** | SwiftUI components: settings, paywall pieces, toast, empty state, disclaimer, Dynamic Type helpers, `Color(hex:)`, `Haptics` | SwiftUI (+ StoreKit bridge under `canImport`) |
| **`PortfolioCore`** | Non-UI utilities: Keychain, App Group store, review-prompt policy, reminder scheduler, WatchLink, NetworkMonitor, image downscaling + thumbnail cache, CSV, date formatting, `AnyEncodable`, launch flags, SwiftData recovery | Foundation, Security, UserNotifications, WatchConnectivity, Network, ImageIO, SwiftData — **no SwiftUI** |

Add whichever products you use to the target (`PortfolioKit` does **not**
re-export `PortfolioCore`; widgets/extensions can take `PortfolioCore` alone).
Both support iOS 17, watchOS 10, macOS 14 and visionOS 1.

Part of the portfolio standard (`Celiador/_standard/PORTFOLIO_STANDARD.md`
§3/§5 and `SHARED_PACKAGES_SURVEY.md` §1.2 in the Apps-AppStore workspace);
settings-screen patterns are distilled in `SETTINGS_BEST_PRACTICES.md` at the
Apps-AppStore workspace root. None of those files is part of this repo — the
essentials are repeated below.

> **Layout note.** These components draw their own rounded, stroked surfaces and
> are designed for a `ScrollView { VStack { … } }` settings screen (Contrarian
> style), **not** inside a `Form`/`List` (where the surfaces would double-inset).
> Apps with a native `Form`/`List` settings screen keep their own rows and adopt
> only the list-agnostic pieces (`Bundle.versionAndBuild`, `LegalLinks`,
> `PortfolioSettings`, `DeleteAccountView` as a pushed screen).

## What's in it — PortfolioKit (UI)

### Settings

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
  no action), plus an optional Restore (hidden automatically for active `.web` /
  `.complimentary` access, where StoreKit restore doesn't apply). Distilled from
  Contrarian + Nassau.
- **`DeleteAccountView(config:onDelete:)`** — the gold-standard destructive flow
  (App Store guideline 5.1.1(v)): typed confirmation phrase, countdown gate that
  starts once the phrase matches,
  App Store-subscription warning, final confirmation dialog, then the app-supplied
  async `onDelete`. Distilled from Nassau + Contrarian.
- **`PortfolioSettings`** — the reference **settings-store pattern**: an
  `@Observable` singleton whose properties persist to `UserDefaults` via `didSet`,
  injected through `@Environment` (from Lunker's `UnitSettings`). Ships
  `appearance` + `hapticsEnabled` — use directly or copy for app-specific stores.
- **`AppearancePicker`** + **`ColorSchemePreference`** — segmented light/dark/system
  picker feeding `.preferredColorScheme` (platform-default style on watchOS).

### Paywall pieces

Plain-value building blocks so every paywall gets the same compliant layout; no
dependency on `PortfolioStoreKit` (a StoreKit 2 bridge is included under
`canImport(StoreKit)`). They follow `PortfolioSettingsTheme` and the view's `.tint`.

- **`PaywallFeatureRow(icon:title:subtitle:)`** — one benefit line.
- **`PaywallProductDisplay`** + **`PaywallProductRow`** — a selectable plan card
  (title, badge, detail, price, period caption, selection mark). Build the
  display from StoreKit with `PaywallProductDisplay(product:isEligibleForIntroOffer:badge:)`
  — it fills "per year", and either the free-trial line (when eligible) or the
  "≈ $2.92 a month" note — or by hand for screenshot rigs / web plans.
- **`SubscriptionPeriodText`** + **`SubscriptionPeriod`** — localized period copy:
  `unit` ("month"/"3 months"), `length` ("1 week", plural-aware), `perPeriod`
  ("per year"), `pricePerPeriod` ("$3.99/month"), `freeTrial` ("1 week free, then
  $3.99/month"), `perMonthNote` ("≈ $2.92 a month", yearly/multi-month only).
  Replaces Stokked `AICreditsView.periodDescription`/`freeTrialText` and
  Contrarian `PaywallView.perMonthNote`.
- **`PaywallLegalFooter(legal:isRestoring:showsRenewalNotice:onRestore:)`** —
  Restore Purchases + Terms of Use (EULA) + Privacy Policy + the auto-renewal
  disclosure (guideline 3.1.2 — its absence got Contrarian 1.1 rejected).

```swift
VStack(spacing: 16) {
    PaywallFeatureRow(icon: "infinity", title: "Unlimited locations",
                      subtitle: "Save every spot you fish.")
    ForEach(store.products) { product in
        PaywallProductRow(
            PaywallProductDisplay(product: product,
                                  isEligibleForIntroOffer: store.isEligibleForIntroOffer,
                                  badge: product.id == annualID ? "Best value" : nil),
            isSelected: selectedID == product.id
        ) { selectedID = product.id }
    }
    PaywallLegalFooter(legal: legal, isRestoring: store.isRestoring) {
        Task { await store.restore() }
    }
}
.tint(.brandAccent)
```

### Feedback & layout

- **`View.toast(_:icon:tint:duration:)`** — transient bottom capsule bound to a
  `String?`; clears itself (or on tap) and is announced to VoiceOver. From
  Celiador `DesignKit`.

  ```swift
  @State private var toast: String?
  content.toast($toast)               // toast = String(localized: "Saved")
  ```
- **`EmptyStateView(_:systemImage:message:actionTitle:action:)`** —
  `ContentUnavailableView` with an optional prominent action (Celiador `DesignKit`).

  ```swift
  EmptyStateView("No catches yet", systemImage: "fish",
                 message: "Log your first catch.", actionTitle: "Log a Catch") { showLog = true }
  ```
- **`View.scaledFont(_:relativeTo:_:)`** / **`ScaledFont`** — a custom point size
  that scales with Dynamic Type while keeping its design; the text style defaults
  to the closest one for the size. **`AdaptiveStack`** — an `HStack` that turns
  into a leading `VStack` at accessibility sizes. Both from Enigma `Theme.swift`
  (`AdaptiveRow` there).

  ```swift
  Text("CHAPTER ONE").scaledFont(13) { .system(size: $0, design: .serif).smallCaps() }
  AdaptiveStack { Text("Sunrise"); Spacer(); Text(time) }
  ```
- **`View.permissionDeniedAlert(isPresented:title:message:)`** — the "access is
  off → Open Settings / Not Now" alert (OK only on watchOS, which has no Settings
  deep link). `AppSettingsLink.url` exposes the per-platform URL.

  ```swift
  .permissionDeniedAlert(isPresented: $cameraDenied, title: "Camera Access Is Off",
                         message: "Allow camera access in Settings to scan labels.")
  ```
- **`DisclaimerView(title:bodyText:icon:points:confirmLabel:acceptLabel:onAccept:)`**
  — the first-run safety gate (guideline 1.4): scrollable copy, optional
  `DisclaimerPoint`s, an "I understand" switch gating Continue. Otta = Svamp.

  ```swift
  @AppStorage("disclaimer_accepted_v1") private var accepted = false
  if !accepted {
      DisclaimerView(title: "Before you forage",
                     bodyText: "Svamp suggests candidates; it never certifies edibility.") {
          accepted = true
      }
  }
  ```

### Small helpers

- **`Color(hex:)`** — `init?(hex: String)` for `RGB` / `RRGGBB` / `RRGGBBAA`
  (optional `#`/`0x`, whitespace-tolerant, `nil` on garbage) and
  `init(hex: UInt, opacity:)` for `0xRRGGBB` literals. Replaces Jeroboam
  `LandingView`, Carpe Vitem `InsightsService`, Ariman `Theme`, Celiador `Theme`
  (and Stokked's three copies). 8 digits are **CSS order RRGGBBAA** — Jeroboam's
  helper read them as AARRGGBB, but no call site used 8 digits.

  ```swift
  static let brand = Color(hex: "#1A5045") ?? .accentColor
  static let gold = Color(hex: 0xF1C761)
  ```
- **`Haptics`** — `tap()`, `select()`, `success()`, `warning()`, `error()`,
  `impact(_:)`; UIKit generators on iOS, `WKInterfaceDevice` on watchOS, no-op on
  macOS/visionOS. `Haptics.isEnabled` is the global switch (bind it to
  `PortfolioSettings.hapticsEnabled`). Replaces Celiador `DesignKit.Haptics` and
  Stokked `DesignSystem.Haptics`.

  ```swift
  Haptics.isEnabled = settings.hapticsEnabled
  Button("Save") { Haptics.success(); save() }
  ```

## What's in it — PortfolioCore (non-UI)

`import PortfolioCore`. Everything is `Sendable`/actor-correct under Swift 6.

### `Keychain` — generic-password store

Replaces ~10 wrappers (Otta ×2, Svamp, Sextant, Lunker, Contrarian, Ariman, Carpe
Vitem, Equinox, Enigma, Celiador, Stokked Wholesale; most complete source: Otta
`Security/KeychainService`). Writes are **update-then-add** (`SecItemUpdate`, then
`SecItemAdd` only on `errSecItemNotFound`) with a match query of class + service +
account (+ group) only — it does **not** reproduce the Otta `KeychainHelper` bug
(delete query containing `kSecValueData`, so the old item survived and every add
failed as a duplicate).

```swift
let keychain = Keychain(service: "se.crawik.otta",
                        accessGroup: nil, accessibility: .afterFirstUnlock)
try keychain.set(tokenData, for: "refresh")      // Data
try keychain.set("abc", for: "refresh")          // String (raw UTF-8)
try keychain.set(session, for: "session")        // any Codable (JSON)
let token = try keychain.string(for: "refresh")
let session = try keychain.get(Session.self, for: "session")
try keychain.remove("session"); try keychain.removeAll()   // this service only
```

All `SecItem*` calls go through the `KeychainBackend` protocol;
`InMemoryKeychainBackend` mirrors the real matching/duplicate semantics for unit
tests and previews (`swift test` on macOS has no keychain entitlement).

### `AppGroupStore` — Codable snapshots for widgets/extensions

Replaces Sextant `SharedStore`, Celiador `WidgetShared`, Otta
`WidgetSnapshotWriter` (and the Lunker/Equinox/Jeroboam/Stokked copies).

```swift
let store = AppGroupStore(groupID: "group.com.sextant.crawik")
try store.write(snapshot, as: "conditions.json", reloadWidgets: true)
let snapshot = try store.read(ConditionsSnapshot.self, from: "conditions.json") // nil if absent
store.defaults?.set(true, forKey: "isPro")        // the group's UserDefaults suite
```

Atomic writes; `read` returns `nil` for a missing file and throws for a corrupt
one; `reloadWidgets(kind:)` is a no-op where WidgetKit isn't available. App
Groups are per device — use `WatchLink` to reach the watch.

### `ReviewPromptPolicy` — when to ask for a review

Port of Otta `ReviewPrompt` + its tests, generalized: string milestone keys (or any
`RawRepresentable<String>`), `milestonesRequired` (3), at most **once per app
version**, `minimumDaysBetweenPrompts` (120), injectable `defaults`/`now`/`version`.
`keyPrefix: "review"` keeps Otta's existing `UserDefaults` keys. Replaces the ad-hoc
logic in Lunker and Equinox.

```swift
@Environment(\.requestReview) private var requestReview
private let reviews = ReviewPromptPolicy()

if reviews.record("entrySaved", promptAllowed: outcome.isGoodMoment) { requestReview() }
```

### `ReminderScheduler` — reconcile local notifications by prefix

The remove-by-prefix → re-add loop from Jeroboam `DrinkingWindowNotificationService`,
ThenCam `SceneReminderCenter` (also Carpe Vitem, Stokked, Contrarian `DailyReminder`).
Only identifiers with your prefix are touched; stale ones are removed, the new set is
(re-)added, `limit:` caps the plan under the 64-pending budget. The result reports
removed / added / skipped / failed identifiers. `NotificationCenterProtocol` is the
test seam (`SystemNotificationCenter` is the real one).

```swift
let requests = plan.map { UNNotificationRequest(identifier: "drinking-window." + $0.id,
                                                content: $0.content, trigger: $0.trigger) }
await ReminderScheduler().reschedule(prefix: "drinking-window.", requests: requests, limit: 48)
await ReminderScheduler().removeAll(prefix: "drinking-window.")   // feature switched off
```

### `WatchLink` — WatchConnectivity base (iOS + watchOS)

`WatchLink.shared`, an `@Observable @MainActor` singleton distilled from Sextant
`WatchLink`, Lunker `WatchSync` and Equinox `WatchSync` (also replaces the Stokked,
Nassau and Celiador variants):

- `activate()` — idempotent; call at launch on both sides.
- `updateContext(_:replacing:)` — merges keys into the application context, adds
  `sentAt` (so identical payloads still deliver), stays **pending until the session
  is activated** and, on iPhone, the watch app is installed; re-sent after switching
  watches.
- `send(_:reliable:)` — live `sendMessage` when reachable, otherwise (or on failure)
  `transferUserInfo`; queued in memory before activation. `reliable: false` = live only.
- `onContext` / `onMessage` — handlers; anything received earlier is replayed.
- Observable `isReachable`, `activationState`, `lastError`.

```swift
WatchLink.shared.activate()
WatchLink.shared.updateContext(["snapshot": try JSONEncoder().encode(snapshot)])   // phone
WatchLink.shared.onContext = { ctx in model.apply(ctx["snapshot"] as? Data) }       // watch
WatchLink.shared.send(["type": "mob", "at": Date().timeIntervalSince1970])         // watch → phone
```

### `NetworkMonitor` — reachability

Stokked/Carpe Vitem `NetworkMonitor` (`@Observable @MainActor`, `NWPathMonitor`):
`isConnected`, `isExpensive`, `isConstrained`, `connectionType`,
`hasReceivedInitialUpdate`, and Stokked's `simulateOffline` override.
`NetworkMonitor.shared` assumes connected until the first update (Carpe Vitem);
`NetworkMonitor(assumeConnected: false)` starts offline (Stokked).

```swift
if NetworkMonitor.shared.isConnected { await sync.pushPending() }
```

### `ImageDownscaler` + `ThumbnailCache`

`ImageDownscaler` is Jeroboam's (best) downscaler rebuilt on ImageIO so it's
platform-neutral (no UIKit — works on macOS/watchOS too): `Data` or `CGImage` in →
JPEG `Data` out, `longestEdge` (2048) / `quality` (0.7), on a detached task. The
`Data` path uses the `CGImageSource` thumbnail API (never decodes full size,
applies EXIF orientation, **strips metadata incl. GPS**). Synchronous building
blocks (`downscaledImage`, `encodeJPEG`, `targetSize`) are public. Replaces Carpe
Vitem's legacy `UIGraphicsBeginImageContext` path and ThenCam's copy.

`ThumbnailCache<Key, Value>` is ThenCam Admin's `ThumbnailLoader` made generic: an
actor over `NSCache` with **in-flight de-duplication** and a loader closure.

```swift
let jpeg = await ImageDownscaler.jpegData(from: pickedData, longestEdge: 2048, quality: 0.7)

let thumbs = ThumbnailCache<String, Data>(countLimit: 300) { path in
    guard let data = try? await storage.download(path: path) else { return nil }
    return await ImageDownscaler.jpegData(from: data, longestEdge: 400)
}
let data = await thumbs.value(for: photo.path)
```

### `CSVWriter` — RFC 4180 export

From Jeroboam `DataExportFormatter` (Carpe Vitem's `escapeCSV` missed CR and edge
whitespace). `field`, `row`, `document(header:rows:)` with CRLF line ends, opt-in
`formulaGuard` against CSV injection (`'`-prefix `= + - @ TAB CR`; off by default
because it also prefixes negative numbers) + `removingFormulaGuard` for imports,
and a locale-independent `number(_:)`.

```swift
let csv = CSVWriter.document(header: ["Name", "Vintage", "Notes"],
                             rows: wines.map { [$0.name, String($0.vintage), $0.notes ?? ""] })
```

### `PortfolioDateFormat` — cached, localized date helpers

The Lunker ≈ Sextant ≈ Equinox `DateFormattingUtils` plus Celiador
`RelativeTime.short`, with formatters cached per (template, zone, locale) behind a
lock (safe from any thread): `time(_:timeZone:)` ("--:--" for nil), `shortDate`,
`shortDateWithYear`, `monthYear`, `format(_:template:)`, `duration(_:)` ("14h 32m",
localized units), `daysBetween(from:to:timeZone:)`, `relativeShort(_:now:)` /
`relativeShort(iso:)` ("now" / "4m" / "3h" / "2d" / "Mar 5"), `parseISO8601`.

```swift
PortfolioDateFormat.time(sunrise, timeZone: location.timeZone)
PortfolioDateFormat.relativeShort(iso: message.createdAt)
```

(`formatDaysUntil` — "Today"/"in 3 days" — stays in the apps: it needs their
catalogs' plural strings; `Date.RelativeFormatStyle` is the system alternative.)

### `AnyEncodable`, `LaunchFlags`

- **`AnyEncodable`** — type-erased `Encodable` for dynamic PostgREST payloads
  (Stokked, copied twice there): `["name": AnyEncodable(list.name)]`.
- **`LaunchFlags`** — screenshot/demo switches (Jeroboam `ScreenshotMode`, ThenCam
  `DemoSeed`, Equinox env hooks, fastlane snapshot). A flag matches an exact launch
  argument or the derived env var (`-premium` → `PREMIUM`, truthy unless
  `0/false/no`). `LaunchFlags.isScreenshotMode` covers `SCREENSHOT_MODE`,
  `-FASTLANE_SNAPSHOT`, `--screenshot-mode`. Gate paid unlocks behind `#if DEBUG`
  in the app.

  ```swift
  if LaunchFlags.isScreenshotMode { DemoData.seed() }
  if LaunchFlags.has("-premium") { store.unlockForScreenshots() }
  let tab = LaunchFlags.current.value(for: "-tab").flatMap(Int.init)
  let legacyTab = LaunchFlags.current.suffixNumber(afterPrefix: "SCREENSHOT_TAB_")
  ```

### `SwiftDataRecovery` (`canImport(SwiftData)`)

ThenCam's `makeContainer`: on an incompatible store the files (`.store`,
`-wal`, `-shm`, `.<name>_SUPPORT`) are **moved aside, never deleted**, into
`StoreRecovery/<unix time>/`, the container is retried fresh, and — optionally —
falls back to in-memory so the app doesn't crash-loop.

```swift
let container = try SwiftDataRecovery.makeContainer(
    for: VaultPhoto.self, Project.self,
    configurations: ModelConfiguration(cloudKitDatabase: .none)
) { error, backup in AppLog.reportError("swiftdata.recovered", error) }
```

### Deferred

- **Speech dictation** (Stokked `SpeechService`, Contrarian `VoiceDictation`) —
  not extracted yet: it needs device testing (simulator speech is unreliable) and
  the two copies differ in on-device/locale policy. Candidate for a later release.

## Localization

PortfolioKit ships its own `Resources/Localizable.xcstrings` (en source; sv, de,
fr, es marked *needs review*) resolved via `Bundle.module`, so built-in copy
("Version", "Privacy Policy", "Restore Purchases", the delete-account flow, the
paywall period/trial copy and renewal disclosure, "Open Settings", "Continue", …)
is translated without the app carrying those keys. Period lengths ("%lld days",
…) use plural variations. `PortfolioCore` has no catalog: its only user-visible
text comes from system formatters, so it follows the locale automatically.

Text **you** pass follows SwiftUI's `Text` rule: a string **literal** becomes a
`LocalizedStringResource` looked up in your app's string catalog; a `String`
**variable** is shown verbatim. `InfoRow`/`LegalLinkRow` values, `planName` and
`DeleteAccountConfig.confirmationPhrase` are always verbatim.

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
5. **Utilities** → swap each copied helper for its `PortfolioCore` / `PortfolioKit`
   counterpart (each section above names the copies it replaces), deleting the
   app's copy in the same commit.

### Adoption notes (name clashes)

- **Equinox `Bundle.buildNumber`** — Equinox's `Models/BundleExtensions.swift`
  declares its own `Bundle.buildNumber` (plus `appVersionString` /
  `marketingVersion`). With PortfolioKit imported, `Bundle.main.buildNumber` is
  **ambiguous** (both are extensions on a Foundation type, so neither shadows the
  other). When Equinox adopts PortfolioKit, delete its `buildNumber` and use
  PortfolioKit's (same semantics, falls back to `"1"`); `appVersionString` maps to
  `versionAndBuild`. PortfolioKit's public API is intentionally not renamed.
- **`Color(hex:)`** — same situation: Jeroboam's non-failable `init(hex: String)`,
  Carpe Vitem's `init?(hex:)`, Ariman's `init(hex: UInt)` and Celiador's
  `init(hex:)` collide with PortfolioKit's. Delete the app copy when adopting;
  Jeroboam/Celiador call sites need a fallback (`?? .accentColor`) because the
  shared initializer is failable.
- **Type names** (`Keychain` in Ariman, `Haptics` in Celiador/Stokked,
  `EmptyStateView` in Celiador, `DisclaimerView` in Otta/Svamp, `NetworkMonitor`
  in Stokked/Carpe Vitem, `WatchLink` in Sextant, `AnyEncodable` in Stokked) — an
  app's own type shadows the imported one, so importing compiles; qualify
  (`PortfolioCore.Keychain`) until the app copy is removed.
- **Keychain service** — pass the service string the app already uses
  (`se.crawik.otta`, `se.ariman.app`, …) so existing items are still found. Svamp's
  `KeychainHelper` stored items **without** a service attribute; those are not
  matched by a service-scoped `Keychain` — migrate them once (read with a
  service-less query, write via `Keychain`, delete the old item).
- **Review prompt** — Otta keeps its progress by using the default
  `keyPrefix: "review"`.

## Versioning

Tagged releases; apps depend on it by URL + version (CI-safe — resolvable in Xcode
Cloud, unlike a sibling local path). Use `Add Local…` only for local development,
never in a committed project.

**0.3.0 (unreleased)** — new **`PortfolioCore`** product (`Keychain`,
`AppGroupStore`, `ReviewPromptPolicy`, `ReminderScheduler`, `WatchLink`,
`NetworkMonitor`, `ImageDownscaler` + `ThumbnailCache`, `CSVWriter`,
`PortfolioDateFormat`, `AnyEncodable`, `LaunchFlags`, `SwiftDataRecovery`), and
PortfolioKit UI additions: `Color(hex:)`, `Haptics`, `toast`, `EmptyStateView`,
`scaledFont`/`AdaptiveStack`, `permissionDeniedAlert`, `DisclaimerView`, and the
paywall pieces (`PaywallFeatureRow`, `PaywallProductRow`/`PaywallProductDisplay`,
`SubscriptionPeriodText`, `PaywallLegalFooter`). New strings in the package
catalog (sv/de/fr/es *needs review*). Purely additive — no source breaks for 0.2.0
call sites (but see the name-clash notes above when adopting).

**0.2.0** — watchOS + visionOS now compile; localization via
the package string catalog; delete countdown starts when the phrase matches;
warning haptic no longer fires on dismiss; Restore hidden for web/complimentary;
locale-aware section headers. Source-breaking for a few call sites:
`DeleteAccountConfig` copy fields are `LocalizedStringResource`
(`deletedItems: [LocalizedStringResource]`), `AboutSection(title:credit:)` take
`LocalizedStringResource`, and `DeleteAccountView`'s `onDelete` is `@MainActor`.
Existing `SettingsSection`/`InfoRow`/`StatusCard`/`LegalLinkRow` calls compile
unchanged.

## Build / test

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
# every declared platform must compile (iOS, watchOS, visionOS, macOS) — the
# PortfolioKit-Package scheme builds both products:
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -scheme PortfolioKit-Package -destination 'generic/platform=watchOS' build
```

(The plain Command Line Tools can't link the SPM manifest; point at a full Xcode.)
