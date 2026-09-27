import Foundation

extension LocalizedStringResource {
    /// A string owned by PortfolioKit, looked up in the package's own
    /// `Localizable.xcstrings` (`Bundle.module`) rather than the app's main
    /// bundle, so the shared components are translated without every app having
    /// to carry the same keys.
    ///
    /// Strings the *app* passes in (section titles, row labels, config copy) are
    /// plain `LocalizedStringResource` literals created in the app, so they
    /// resolve against the app's own bundle as usual.
    @usableFromInline
    static func portfolioKit(
        _ keyAndValue: String.LocalizationValue,
        comment: StaticString? = nil
    ) -> LocalizedStringResource {
        LocalizedStringResource(
            keyAndValue,
            bundle: .atURL(Bundle.module.bundleURL),
            comment: comment
        )
    }
}
