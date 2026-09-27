import SwiftUI

/// The legal/support URLs an app links from its About/Settings screen.
/// Centralizes the hardcoded URL literals scattered across the portfolio and
/// defaults `termsOfUse` to Apple's standard EULA (the common case).
public struct LegalLinks: Sendable, Hashable {
    /// Apple's standard end-user license agreement — the default for apps that
    /// don't ship their own terms.
    public static let appleStandardEULA = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    public var privacyPolicy: URL
    public var termsOfUse: URL
    public var support: URL?

    public init(privacyPolicy: URL, termsOfUse: URL = LegalLinks.appleStandardEULA, support: URL? = nil) {
        self.privacyPolicy = privacyPolicy
        self.termsOfUse = termsOfUse
        self.support = support
    }
}

/// A tappable row that opens an external URL, with the trailing
/// `arrow.up.right` glyph the portfolio uses to signal "leaves the app".
public struct LegalLinkRow: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.portfolioSettingsTheme) private var theme

    private let title: Text
    private let value: String?
    private let url: URL

    /// - Parameters:
    ///   - title: localized from the app's string catalog when a literal is passed.
    ///   - value: optional trailing value, shown verbatim (e.g. a domain).
    public init(_ title: LocalizedStringResource, value: String? = nil, url: URL) {
        self.init(title: Text(title), value: value, url: url)
    }

    /// Verbatim variant for runtime strings.
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, value: String? = nil, url: URL) {
        self.init(title: Text(verbatim: String(title)), value: value, url: url)
    }

    init(title: Text, value: String?, url: URL) {
        self.title = title
        self.value = value
        self.url = url
    }

    public var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                title.foregroundStyle(theme.label)
                Spacer()
                if let value {
                    Text(verbatim: value).foregroundStyle(theme.value)
                }
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(theme.label)
                    .accessibilityHidden(true)
            }
            .settingsRowSurface(theme)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }
}
