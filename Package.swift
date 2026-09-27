// swift-tools-version: 6.0
import PackageDescription

// Shared, backend-free UI + small helpers for the Apps-AppStore family.
// Pure SwiftUI/Foundation, no external dependencies — apps depend on
// `PortfolioKit` to stop copy-pasting settings components, the version
// string, and legal links. See _standard/PORTFOLIO_STANDARD.md §3/§5.
//
// The package's own UI strings live in Resources/Localizable.xcstrings and are
// resolved against `Bundle.module` (see Localization.swift).
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
    ],
    targets: [
        .target(
            name: "PortfolioKit",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "PortfolioKitTests", dependencies: ["PortfolioKit"]),
    ]
)
