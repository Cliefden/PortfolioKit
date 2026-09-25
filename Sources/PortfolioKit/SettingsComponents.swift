import SwiftUI

/// A settings section: an uppercased, tracked header above its content.
/// (Genericized from Contrarian's `section()` builder.)
public struct SettingsSection<Content: View>: View {
    @Environment(\.portfolioSettingsTheme) private var theme
    private let title: String
    @ViewBuilder private let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .tracking(1.5)
                .foregroundStyle(theme.label)
            content
        }
    }
}

/// A key/value row on a rounded, stroked surface.
/// (Genericized from Contrarian's `infoRow()`.)
public struct InfoRow: View {
    @Environment(\.portfolioSettingsTheme) private var theme
    private let label: String
    private let value: String

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        HStack {
            Text(label).foregroundStyle(theme.label)
            Spacer()
            Text(value)
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
    private let title: String
    private let detail: String
    private let icon: String
    private let tint: Color

    public init(title: String, detail: String, icon: String, tint: Color) {
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
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: theme.titleDesign).weight(.bold))
                    .foregroundStyle(tint)
                Text(detail)
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
