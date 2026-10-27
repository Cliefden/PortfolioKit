import SwiftUI

public extension Color {
    /// A color from a CSS-style hex string: `RGB`, `RRGGBB` or `RRGGBBAA`, with
    /// an optional `#` (or `0x`) prefix and surrounding whitespace. Returns `nil`
    /// for anything else, so a typo in a spec/server color is visible instead of
    /// silently black. sRGB.
    ///
    /// Replaces the four portfolio variants (Jeroboam `LandingView`, Carpe Vitem
    /// `InsightsService`, Ariman `Theme`, Celiador `Theme`).
    ///
    /// ```swift
    /// Color(hex: "#1A5045") ?? .accentColor
    /// Color(hex: "F1C761CC")      // 80 % opacity
    /// ```
    ///
    /// > Note: 8 digits are **RRGGBBAA** (CSS order). Jeroboam's old helper read
    /// > them as AARRGGBB; no call site in the portfolio used 8 digits.
    init?(hex: String) {
        guard let rgba = HexColor.parse(hex) else { return nil }
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    /// A color from a 24-bit `0xRRGGBB` literal (Ariman's palette style).
    ///
    /// ```swift
    /// static let arimanGold = Color(hex: 0xF1C761)
    /// ```
    init(hex: UInt, opacity: Double = 1) {
        let rgba = HexColor.components(rgb: hex)
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: opacity)
    }
}

/// Pure hex parsing behind `Color(hex:)`, separate so it can be unit-tested.
struct HexColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static func parse(_ string: String) -> HexColor? {
        var hex = Substring(string.trimmingCharacters(in: .whitespacesAndNewlines))
        if hex.hasPrefix("#") {
            hex = hex.dropFirst()
        } else if hex.lowercased().hasPrefix("0x") {
            hex = hex.dropFirst(2)
        }
        guard [3, 6, 8].contains(hex.count),
              hex.allSatisfy(\.isHexDigit),
              let value = UInt64(hex, radix: 16) else { return nil }
        switch hex.count {
        case 3:
            return HexColor(
                red: Double((value >> 8) & 0xF) * 17 / 255,
                green: Double((value >> 4) & 0xF) * 17 / 255,
                blue: Double(value & 0xF) * 17 / 255,
                alpha: 1
            )
        case 6:
            return components(rgb: UInt(value))
        default:
            var rgb = components(rgb: UInt(value >> 8))
            rgb.alpha = Double(value & 0xFF) / 255
            return rgb
        }
    }

    static func components(rgb: UInt) -> HexColor {
        HexColor(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
