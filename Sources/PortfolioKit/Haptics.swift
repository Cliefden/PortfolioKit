import Foundation
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// Imperative haptic feedback for button handlers and async completions (for
/// state-driven feedback prefer SwiftUI's `.sensoryFeedback`). Merges Celiador
/// `DesignKit.Haptics` and Stokked `DesignSystem.Haptics`.
///
/// UIKit feedback generators on iOS, `WKInterfaceDevice` on watchOS, and a
/// silent no-op on macOS/visionOS — so shared code can call it unconditionally.
///
/// ```swift
/// Button("Save") { Haptics.success(); save() }
///
/// // honour the user's setting once, at launch / when it changes
/// Haptics.isEnabled = settings.hapticsEnabled
/// ```
@MainActor
public enum Haptics {
    /// Impact weights (mapped to the closest equivalent per platform).
    public enum Impact: Sendable, CaseIterable {
        case light, medium, heavy, soft, rigid
    }

    /// Global kill switch, e.g. bound to ``PortfolioSettings/hapticsEnabled``.
    public static var isEnabled = true

    /// A light tap — chips, small toggles.
    public static func tap() { impact(.light) }

    /// A selection change — pickers, steppers, segmented controls.
    public static func select() {
        guard isEnabled else { return }
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    /// A completed action.
    public static func success() { notify(.success) }

    /// Something needs attention (also before destructive confirmations).
    public static func warning() { notify(.warning) }

    /// A failed action.
    public static func error() { notify(.error) }

    /// A physical impact of the given weight.
    public static func impact(_ style: Impact = .medium) {
        guard isEnabled else { return }
        #if os(iOS)
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .soft: .soft
        case .rigid: .rigid
        }
        UIImpactFeedbackGenerator(style: uiStyle).impactOccurred()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(style == .heavy || style == .rigid ? .directionUp : .click)
        #endif
    }

    private enum Notification { case success, warning, error }

    private static func notify(_ type: Notification) {
        guard isEnabled else { return }
        #if os(iOS)
        let uiType: UINotificationFeedbackGenerator.FeedbackType = switch type {
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
        UINotificationFeedbackGenerator().notificationOccurred(uiType)
        #elseif os(watchOS)
        let haptic: WKHapticType = switch type {
        case .success: .success
        case .warning: .retry
        case .error: .failure
        }
        WKInterfaceDevice.current().play(haptic)
        #endif
    }
}
