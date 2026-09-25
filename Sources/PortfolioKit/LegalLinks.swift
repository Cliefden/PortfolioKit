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

    private let title: String
    private let value: String?
    private let url: URL

    public init(_ title: String, value: String? = nil, url: URL) {
        self.title = title
        self.value = value
        self.url = url
    }

    public var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                Text(title).foregroundStyle(theme.label)
                Spacer()
                if let value {
                    Text(value).foregroundStyle(theme.value)
                }
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(theme.label)
            }
            .settingsRowSurface(theme)
        }
        .buttonStyle(.plain)
    }
}
