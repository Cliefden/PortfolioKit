import SwiftUI

/// Scales a custom font size with Dynamic Type while keeping its design
/// (serif, small caps, italics) — Enigma `Theme.ScaledFont`. Prefer
/// ``SwiftUICore/View/scaledFont(_:relativeTo:_:)``.
public struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let make: (CGFloat) -> Font

    /// - Parameters:
    ///   - base: the point size at the default (`.large`) text size.
    ///   - style: the text style whose scaling curve to follow.
    ///   - make: builds the font from the scaled size.
    public init(base: CGFloat, relativeTo style: Font.TextStyle, make: @escaping (CGFloat) -> Font) {
        _size = ScaledMetric(wrappedValue: base, relativeTo: style)
        self.make = make
    }

    public func body(content: Content) -> some View {
        content.font(make(size))
    }

    /// The text style whose default size is closest to `pointSize` (iOS
    /// defaults at `.large`), used when no style is given.
    public nonisolated static func textStyle(forPointSize pointSize: CGFloat) -> Font.TextStyle {
        let styles: [(Font.TextStyle, CGFloat)] = [
            (.caption2, 11), (.caption, 12), (.footnote, 13), (.subheadline, 15),
            (.callout, 16), (.body, 17), (.title3, 20), (.title2, 22), (.title, 28), (.largeTitle, 34),
        ]
        return styles.min { abs($0.1 - pointSize) < abs($1.1 - pointSize) }!.0
    }
}

public extension View {
    /// A custom-size font that scales with Dynamic Type.
    ///
    /// ```swift
    /// Text("CHAPTER ONE")
    ///     .scaledFont(13) { .system(size: $0, design: .serif).smallCaps() }
    /// Text(price).scaledFont(28, relativeTo: .title)
    /// ```
    ///
    /// - Parameter style: scaling curve; defaults to the text style closest to `size`.
    func scaledFont(
        _ size: CGFloat,
        relativeTo style: Font.TextStyle? = nil,
        _ make: @escaping (CGFloat) -> Font = { .system(size: $0) }
    ) -> some View {
        modifier(ScaledFont(base: size, relativeTo: style ?? ScaledFont.textStyle(forPointSize: size), make: make))
    }
}

/// An `HStack` that becomes a leading-aligned `VStack` at large (by default,
/// accessibility) text sizes, where a row would no longer fit — Enigma
/// `AdaptiveRow`.
///
/// ```swift
/// AdaptiveStack {
///     Text("Sunrise")
///     Spacer()
///     Text(time).monospacedDigit()
/// }
/// ```
public struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    private let spacing: CGFloat
    private let alignment: VerticalAlignment
    private let verticalAlignment: HorizontalAlignment
    private let threshold: DynamicTypeSize
    private let content: Content

    /// - Parameters:
    ///   - spacing: horizontal spacing (the vertical layout uses 60 % of it).
    ///   - alignment: row alignment in horizontal mode.
    ///   - verticalAlignment: column alignment in vertical mode.
    ///   - threshold: the first type size that stacks vertically.
    public init(
        spacing: CGFloat = 12,
        alignment: VerticalAlignment = .center,
        verticalAlignment: HorizontalAlignment = .leading,
        threshold: DynamicTypeSize = .accessibility1,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.verticalAlignment = verticalAlignment
        self.threshold = threshold
        self.content = content()
    }

    public var body: some View {
        let layout = Self.isVertical(typeSize, threshold: threshold)
            ? AnyLayout(VStackLayout(alignment: verticalAlignment, spacing: spacing * 0.6))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
        layout { content }
    }

    nonisolated static func isVertical(_ size: DynamicTypeSize, threshold: DynamicTypeSize) -> Bool {
        size >= threshold
    }
}
