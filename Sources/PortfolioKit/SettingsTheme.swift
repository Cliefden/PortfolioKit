import SwiftUI

/// Styling knobs for the PortfolioKit settings components. Defaults are
/// system-color based so a component looks native out of the box; brand apps
/// (e.g. Contrarian) override via `.portfolioSettingsTheme(_:)` to keep their
/// palette. Cross-platform safe — no UIKit-only colors.
public struct PortfolioSettingsTheme: Sendable, Hashable {
    /// Secondary text — section headers, row labels, captions.
    public var label: Color
    /// Primary text — row values.
    public var value: Color
    /// Row/panel fill.
    public var panel: Color
    /// Row/panel border stroke.
    public var line: Color
    /// Corner radius for rows and cards.
    public var cornerRadius: CGFloat
    /// Font design for card/section titles (`.serif` for Contrarian, etc.).
    public var titleDesign: Font.Design

    public init(
        label: Color = .secondary,
        value: Color = .primary,
        panel: Color = Color.primary.opacity(0.05),
        line: Color = Color.primary.opacity(0.12),
        cornerRadius: CGFloat = 12,
        titleDesign: Font.Design = .default
    ) {
        self.label = label
        self.value = value
        self.panel = panel
        self.line = line
        self.cornerRadius = cornerRadius
        self.titleDesign = titleDesign
    }

    public static let `default` = PortfolioSettingsTheme()
}

private struct PortfolioSettingsThemeKey: EnvironmentKey {
    static let defaultValue = PortfolioSettingsTheme.default
}

public extension EnvironmentValues {
    var portfolioSettingsTheme: PortfolioSettingsTheme {
        get { self[PortfolioSettingsThemeKey.self] }
        set { self[PortfolioSettingsThemeKey.self] = newValue }
    }
}

public extension View {
    /// Apply a settings theme to all PortfolioKit components in this subtree.
    func portfolioSettingsTheme(_ theme: PortfolioSettingsTheme) -> some View {
        environment(\.portfolioSettingsTheme, theme)
    }
}

extension View {
    /// Shared row/card surface: padded, filled, rounded, stroked per theme.
    func settingsRowSurface(_ theme: PortfolioSettingsTheme, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.line))
    }
}
