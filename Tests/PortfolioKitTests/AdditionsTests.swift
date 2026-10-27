import Testing
import SwiftUI
@testable import PortfolioKit

// MARK: - Color(hex:)

@Suite struct HexColorTests {
    @Test func parsesSixDigitsWithOrWithoutPrefix() {
        let expected = HexColor(red: 0x1A / 255.0, green: 0x50 / 255.0, blue: 0x45 / 255.0, alpha: 1)
        #expect(HexColor.parse("#1A5045") == expected)
        #expect(HexColor.parse("1a5045") == expected)
        #expect(HexColor.parse("  0x1A5045\n") == expected)
    }

    @Test func parsesThreeDigitShorthand() {
        #expect(HexColor.parse("#F80") == HexColor(red: 1, green: 0x88 / 255.0, blue: 0, alpha: 1))
    }

    @Test func parsesEightDigitsAsRGBA() {
        let color = HexColor.parse("#FF000080")
        #expect(color?.red == 1)
        #expect(color?.green == 0)
        #expect(color?.alpha == 128 / 255.0)
    }

    @Test func rejectsInvalidInput() {
        for bad in ["", "#", "12345", "#GGGGGG", "1234567", "#123456789", "red", "+12345"] {
            #expect(HexColor.parse(bad) == nil, "\(bad)")
        }
        #expect(Color(hex: "nope") == nil)
    }

    @Test func uintInitializer() {
        #expect(HexColor.components(rgb: 0xF1C761) == HexColor(red: 0xF1 / 255.0, green: 0xC7 / 255.0, blue: 0x61 / 255.0, alpha: 1))
    }

    @Test func colorResolvesToParsedComponents() throws {
        let resolved = try #require(Color(hex: "#336699")).resolve(in: EnvironmentValues())
        #expect(abs(Double(resolved.red) - 0.2) < 0.01 || abs(Double(resolved.linearRed) - 0.0331) < 0.01)
        let withOpacity = Color(hex: 0x336699, opacity: 0.5).resolve(in: EnvironmentValues())
        #expect(abs(Double(withOpacity.opacity) - 0.5) < 0.001)
    }
}

// MARK: - SubscriptionPeriodText

private let en = Locale(identifier: "en_US")
private let sv = Locale(identifier: "sv_SE")

@Suite struct SubscriptionPeriodTextTests {
    @Test func unitIsSingularForOneAndCountedOtherwise() {
        #expect(SubscriptionPeriodText.unit(.monthly, locale: en) == "month")
        #expect(SubscriptionPeriodText.unit(.yearly, locale: en) == "year")
        #expect(SubscriptionPeriodText.unit(.init(value: 3, unit: .month), locale: en) == "3 months")
        #expect(SubscriptionPeriodText.unit(.monthly, locale: sv) == "månad")
    }

    @Test func lengthIsPluralized() {
        #expect(SubscriptionPeriodText.length(.weekly, locale: en) == "1 week")
        #expect(SubscriptionPeriodText.length(.init(value: 3, unit: .day), locale: en) == "3 days")
        #expect(SubscriptionPeriodText.length(.init(value: 1, unit: .day), locale: sv) == "1 dag")
        #expect(SubscriptionPeriodText.length(.init(value: 2, unit: .week), locale: sv) == "2 veckor")
    }

    @Test func pricePerPeriodAndCaption() {
        #expect(SubscriptionPeriodText.pricePerPeriod("$3.99", period: .monthly, locale: en) == "$3.99/month")
        #expect(SubscriptionPeriodText.perPeriod(.yearly, locale: en) == "per year")
        #expect(SubscriptionPeriodText.perPeriod(.yearly, locale: Locale(identifier: "de_DE")) == "pro Jahr")
    }

    @Test func freeTrialText() {
        #expect(SubscriptionPeriodText.freeTrial(.weekly, then: "$3.99", per: .monthly, locale: en)
                == "1 week free, then $3.99/month")
        #expect(SubscriptionPeriodText.freeTrial(.init(value: 3, unit: .day), then: "39 kr", per: .monthly, locale: sv)
                == "3 dagar gratis, sedan 39 kr/månad")
    }

    @Test func perMonthNoteOnlyForMultiMonthPlans() {
        #expect(SubscriptionPeriodText.perMonthNote(price: Decimal(string: "34.99")!, period: .yearly, currencyCode: "USD", locale: en)
                == "≈ $2.92 a month")
        #expect(SubscriptionPeriodText.perMonthNote(price: 4.99, period: .monthly, currencyCode: "USD", locale: en) == nil)
        #expect(SubscriptionPeriodText.perMonthNote(price: 1, period: .weekly, currencyCode: "USD", locale: en) == nil)
        #expect(SubscriptionPeriodText.perMonthPrice(price: 60, period: .init(value: 6, unit: .month)) == 10)
    }

    @Test func periodMonths() {
        #expect(SubscriptionPeriod.yearly.months == 12)
        #expect(SubscriptionPeriod(value: 2, unit: .year).months == 24)
        #expect(SubscriptionPeriod.weekly.months == nil)
    }
}

// MARK: - New package strings

private func resolve(_ resource: LocalizedStringResource, _ locale: String) -> String {
    var r = resource
    r.locale = Locale(identifier: locale)
    return String(localized: r)
}

@Test func newBuiltInStringsAreLocalized() {
    #expect(resolve(.portfolioKit("Open Settings"), "sv") == "Öppna Inställningar")
    #expect(resolve(.portfolioKit("Continue"), "de") == "Weiter")
    #expect(resolve(.portfolioKit("I understand"), "fr") == "Je comprends")
    #expect(resolve(.portfolioKit("Not Now"), "es") == "Ahora no")
}

// MARK: - Layout helpers

@Test func scaledFontPicksClosestTextStyle() {
    #expect(ScaledFont.textStyle(forPointSize: 13) == .footnote)
    #expect(ScaledFont.textStyle(forPointSize: 17) == .body)
    #expect(ScaledFont.textStyle(forPointSize: 30) == .title)
    #expect(ScaledFont.textStyle(forPointSize: 60) == .largeTitle)
}

@Test func adaptiveStackSwitchesAtThreshold() {
    #expect(!AdaptiveStack<EmptyView>.isVertical(.xxxLarge, threshold: .accessibility1))
    #expect(AdaptiveStack<EmptyView>.isVertical(.accessibility1, threshold: .accessibility1))
    #expect(AdaptiveStack<EmptyView>.isVertical(.xLarge, threshold: .large))
}

@MainActor
@Test func hapticsAreSafeToCallOnEveryPlatform() {
    Haptics.isEnabled = false
    Haptics.tap(); Haptics.select(); Haptics.success(); Haptics.warning(); Haptics.error(); Haptics.impact(.heavy)
    Haptics.isEnabled = true
}

@Test func productDisplayConvenience() {
    let display = PaywallProductDisplay(id: "annual", title: "Annual", price: "$34.99", periodText: "per year", detail: "≈ $2.92 a month")
    #expect(display.id == "annual")
    #expect(display.badge == nil)
}
