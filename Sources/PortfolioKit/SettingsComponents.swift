import SwiftUI

/// A settings section: an uppercased, tracked header above its content.
/// (Genericized from Contrarian's `section()` builder.)
///
/// Pass a string literal to have it localized from your app's string catalog;
/// pass a `String` variable to show it verbatim (same rule as SwiftUI's `Text`).
public struct SettingsSection<Content: View>: View {
    @Environment(\.portfolioSettingsTheme) private var theme
    private let title: Text
    @ViewBuilder private let content: Content

    public init(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
        self.title = Text(title)
        self.content = content()
    }

    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {
        self.title = Text(verbatim: String(title))
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            title
                .textCase(.uppercase) // locale-aware, unlike String.uppercased()
                .font(.caption)
                .tracking(1.5)
                .foregroundStyle(theme.label)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

/// A key/value row on a rounded, stroked surface.
/// (Genericized from Contrarian's `infoRow()`.) The label is localized when a
/// literal is passed; the value is data and always shown verbatim.
public struct InfoRow: View {
    @Environment(\.portfolioSettingsTheme) private var theme
    private let label: Text
    private let value: String

    public init(_ label: LocalizedStringResource, _ value: String) {
        self.label = Text(label)
        self.value = value
    }

    @_disfavoredOverload
    public init<S: StringProtocol>(_ label: S, _ value: String) {
        self.label = Text(verbatim: String(label))
        self.value = value
    }

    public var body: some View {
        HStack {
            label.foregroundStyle(theme.label)
            Spacer()
            Text(verbatim: value)
                .foregroundStyle(theme.value)
                .multilineTextAlignment(.trailing)
        }
        .settingsRowSurface(theme)
    }
}

/// A tinted status card: icon + title + detail on a `tint`-washed surface.
/// (Genericized from Contrarian's `statusCard()`.)
public struct StatusCard: View {
    @Environment(\.portfolioSettingsTheme) private var theme
    private let title: Text
    private let detail: Text
    private let icon: String
    private let tint: Color

    public init(title: LocalizedStringResource, detail: LocalizedStringResource, icon: String, tint: Color) {
        self.init(title: Text(title), detail: Text(detail), icon: icon, tint: tint)
    }

    /// Verbatim variant for runtime strings (also used when a literal is mixed
    /// with a `String` variable).
    @_disfavoredOverload
    public init<T: StringProtocol, D: StringProtocol>(title: T, detail: D, icon: String, tint: Color) {
        self.init(title: Text(verbatim: String(title)), detail: Text(verbatim: String(detail)), icon: icon, tint: tint)
    }

    init(title: Text, detail: Text, icon: String, tint: Color) {
        self.title = title
        self.detail = detail
        self.icon = icon
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                title
                    .font(.system(.headline, design: theme.titleDesign).weight(.bold))
                    .foregroundStyle(tint)
                detail
                    .font(.subheadline)
                    .foregroundStyle(theme.label)
            }
            Spacer()
        }
        .padding(18)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(tint.opacity(0.3)))
    }
}
