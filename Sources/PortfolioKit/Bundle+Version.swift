import Foundation

public extension Bundle {
    /// Marketing version, e.g. `"1.2.3"` (falls back to `"1.0"`).
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// Build number, e.g. `"42"` (falls back to `"1"`).
    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    /// Combined `"version (build)"`, e.g. `"1.2.3 (42)"` — the About-row standard
    /// across the portfolio (previously duplicated in ~8 apps).
    var versionAndBuild: String {
        "\(appVersion) (\(buildNumber))"
    }
}
