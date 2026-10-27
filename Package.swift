// swift-tools-version: 6.0
import PackageDescription

// Shared, backend-free code for the Apps-AppStore family. No external
// dependencies. Two products:
//
// - `PortfolioKit`  — SwiftUI components (settings, paywall pieces, toast,
//   empty state, disclaimer, …) + `Color(hex:)` / `Haptics`.
// - `PortfolioCore` — non-UI utilities (Keychain, App Group store, review-prompt
//   policy, reminder scheduler, WatchLink, NetworkMonitor, image downscaling,
//   CSV, date formatting, launch flags, SwiftData recovery). No SwiftUI.
//
// See _standard/PORTFOLIO_STANDARD.md §3/§5 and SHARED_PACKAGES_SURVEY.md §1.2.
//
// The UI strings live in Sources/PortfolioKit/Resources/Localizable.xcstrings and
// are resolved against `Bundle.module` (see Localization.swift).
let package = Package(
    name: "PortfolioKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "PortfolioKit", targets: ["PortfolioKit"]),
        .library(name: "PortfolioCore", targets: ["PortfolioCore"]),
    ],
    targets: [
        .target(name: "PortfolioCore"),
        .target(
            name: "PortfolioKit",
            // Internal dependency only — PortfolioKit does not re-export
            // PortfolioCore; apps that want the utilities add that product too.
            dependencies: ["PortfolioCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "PortfolioKitTests", dependencies: ["PortfolioKit"]),
        .testTarget(name: "PortfolioCoreTests", dependencies: ["PortfolioCore"]),
    ]
)
