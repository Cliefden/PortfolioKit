import SwiftUI

/// The standard About block: a version row plus Support / Privacy / Terms links,
/// composed from ``InfoRow`` and ``LegalLinkRow``. Replaces the near-identical
/// About sections copy-pasted across the portfolio. Backend-free.
///
/// The built-in labels ("About", "Version", "Support", "Privacy Policy",
/// "Terms of Use") are localized from PortfolioKit's own string catalog.
///
/// ```swift
/// AboutSection(
///     legal: LegalLinks(
///         privacyPolicy: URL(string: "https://crawik.com/lunker/privacy")!,
///         support: URL(string: "https://crawik.com/lunker/support")!
///     )
/// )
/// ```
public struct AboutSection: View {
    private let title: LocalizedStringResource
    private let bundle: Bundle
    private let legal: LegalLinks
    /// Optional trailing credit/attribution line (e.g. data source).
    private let credit: LocalizedStringResource?

    public init(
        title: LocalizedStringResource = .portfolioKit("About"),
        bundle: Bundle = .main,
        legal: LegalLinks,
        credit: LocalizedStringResource? = nil
    ) {
        self.title = title
        self.bundle = bundle
        self.legal = legal
        self.credit = credit
    }

    public var body: some View {
        SettingsSection(title) {
            InfoRow(.portfolioKit("Version"), bundle.versionAndBuild)
            if let support = legal.support {
                LegalLinkRow(.portfolioKit("Support"), url: support)
            }
            LegalLinkRow(.portfolioKit("Privacy Policy"), url: legal.privacyPolicy)
            LegalLinkRow(.portfolioKit("Terms of Use"), url: legal.termsOfUse)
            if let credit {
                Text(credit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
    }
}
