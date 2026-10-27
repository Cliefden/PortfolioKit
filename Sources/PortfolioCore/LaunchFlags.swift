import Foundation

/// Launch-argument / environment switches for screenshot automation and demo
/// data (Jeroboam `ScreenshotMode`, ThenCam `DemoSeed`, Equinox's
/// `EQUINOX_PRESET`, fastlane snapshot).
///
/// ```swift
/// if LaunchFlags.isScreenshotMode { DemoData.seed() }
/// if LaunchFlags.has("-premium") { store.unlockForScreenshots() }
/// let tab = LaunchFlags.current.value(for: "-tab").flatMap(Int.init)   // `-tab 2`
/// ```
///
/// A flag matches an exact launch argument (`-premium`) **or** an environment
/// variable derived from it (`PREMIUM`, see ``environmentKey(for:)``) whose value
/// isn't `0`/`false`/`no`. Launch arguments can't be set on App Store installs,
/// but gate anything that unlocks paid features behind `#if DEBUG` in the app
/// anyway.
public struct LaunchFlags: Sendable {
    /// Arguments that switch on screenshot mode.
    public static let screenshotArguments = ["SCREENSHOT_MODE", "-SCREENSHOT_MODE", "--screenshot-mode", "-FASTLANE_SNAPSHOT"]

    public let arguments: [String]
    public let environment: [String: String]

    public init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.arguments = arguments
        self.environment = environment
    }

    /// The running process's flags.
    public static var current: LaunchFlags { LaunchFlags() }

    /// `true` when launched for App Store screenshots (`SCREENSHOT_MODE`,
    /// `-FASTLANE_SNAPSHOT YES`, or `SCREENSHOT_MODE=1` in the environment).
    public var isScreenshotMode: Bool {
        Self.screenshotArguments.contains { has($0) }
    }

    /// Whether `flag` was passed as an argument or set in the environment.
    public func has(_ flag: String) -> Bool {
        if arguments.contains(flag) { return true }
        guard let value = environment[Self.environmentKey(for: flag)] else { return false }
        return !["0", "false", "no", ""].contains(value.lowercased())
    }

    /// The value following `flag` in the arguments (`-tab 2` → `"2"`), else
    /// the derived environment variable (`TAB=2`).
    public func value(for flag: String) -> String? {
        if let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) {
            return arguments[index + 1]
        }
        return environment[Self.environmentKey(for: flag)]
    }

    /// The integer suffix of an argument starting with `prefix`
    /// (`SCREENSHOT_TAB_2` → `2`, Jeroboam's convention).
    public func suffixNumber(afterPrefix prefix: String) -> Int? {
        arguments.lazy.compactMap { argument -> Int? in
            guard argument.hasPrefix(prefix) else { return nil }
            return Int(argument.dropFirst(prefix.count))
        }.first
    }

    /// `-premium` → `PREMIUM`, `--demo-seed` → `DEMO_SEED`.
    public static func environmentKey(for flag: String) -> String {
        String(flag.drop { $0 == "-" }).uppercased().replacingOccurrences(of: "-", with: "_")
    }

    // MARK: Static conveniences on the current process

    public static var isScreenshotMode: Bool { current.isScreenshotMode }
    public static func has(_ flag: String) -> Bool { current.has(flag) }
}
