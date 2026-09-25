// swift-tools-version: 5.9
import PackageDescription

// Shared, backend-free UI + small helpers for the Apps-AppStore family.
// Pure SwiftUI/Foundation, no external dependencies — apps depend on
// `PortfolioKit` to stop copy-pasting settings components, the version
// string, and legal links. See _standard/PORTFOLIO_STANDARD.md §3/§5.
let package = Package(
    name: "PortfolioKit",
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
        .target(name: "PortfolioKit"),
        .testTarget(name: "PortfolioKitTests", dependencies: ["PortfolioKit"]),
    ]
)
