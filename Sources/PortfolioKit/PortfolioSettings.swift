import SwiftUI
import Observation

/// The user's app-appearance choice. Maps to an optional `ColorScheme`
/// (`nil` == follow the system).
public enum ColorSchemePreference: String, CaseIterable, Sendable, Identifiable {
    case system, light, dark

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    public var label: LocalizedStringResource {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

/// The reference **settings-store pattern** for the portfolio: an `@Observable`
/// singleton whose properties persist to `UserDefaults` via `didSet`, injected
/// through `@Environment`. (Genericized from Lunker's `UnitSettings`.) It ships
/// two settings almost every app needs — appearance + haptics — so apps can use
/// it directly, and serves as the copy-me template for app-specific stores.
///
/// ```swift
/// @main struct MyApp: App {
///     @State private var settings = PortfolioSettings.shared
///     var body: some Scene {
///         WindowGroup {
///             RootView()
///                 .environment(settings)
///                 .preferredColorScheme(settings.appearance.colorScheme)
///         }
///     }
/// }
/// ```
@MainActor
@Observable
public final class PortfolioSettings {
    public static let shared = PortfolioSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let appearance = "portfolio.appearance"
        static let haptics = "portfolio.hapticsEnabled"
    }

    /// Light / dark / follow-system. Drives `.preferredColorScheme`.
    public var appearance: ColorSchemePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// Whether the app should play haptic feedback. Apps gate `.sensoryFeedback`
    /// (or `UIImpactFeedbackGenerator`) on this.
    public var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) }
    }

    /// - Parameter defaults: injectable for tests; production uses `.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appearance = (defaults.string(forKey: Key.appearance))
            .flatMap(ColorSchemePreference.init(rawValue:)) ?? .system
        // `object(forKey:)` distinguishes "never set" (default: on) from "set to false".
        self.hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
    }
}

/// A segmented appearance picker bound to a ``ColorSchemePreference``.
/// Drop it in a settings screen and feed the value to `.preferredColorScheme`.
public struct AppearancePicker: View {
    @Binding private var selection: ColorSchemePreference
    private let title: LocalizedStringResource

    public init(_ title: LocalizedStringResource = "Appearance", selection: Binding<ColorSchemePreference>) {
        self.title = title
        self._selection = selection
    }

    public var body: some View {
        Picker(String(localized: title), selection: $selection) {
            ForEach(ColorSchemePreference.allCases) { pref in
                Text(pref.label).tag(pref)
            }
        }
        .pickerStyle(.segmented)
    }
}
