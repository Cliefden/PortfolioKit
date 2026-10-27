import SwiftUI

/// One highlighted point on a ``DisclaimerView`` (icon + title + explanation).
public struct DisclaimerPoint: Sendable {
    public var icon: String
    public var title: LocalizedStringResource
    public var body: LocalizedStringResource

    public init(icon: String, title: LocalizedStringResource, body: LocalizedStringResource) {
        self.icon = icon
        self.title = title
        self.body = body
    }
}

/// A mandatory first-run safety / liability gate (App Review Guideline 1.4 for
/// apps whose output could cause harm if trusted blindly). Otta and Svamp ship
/// the same screen: scrollable copy, an "I understand" switch, and a Continue
/// button that stays disabled until it's on.
///
/// ```swift
/// @AppStorage("disclaimer_accepted_v1") private var accepted = false
///
/// if !accepted {
///     DisclaimerView(
///         title: "Before you forage",
///         bodyText: "Svamp suggests candidates; it never certifies that anything is safe to eat.",
///         points: [
///             DisclaimerPoint(icon: "list.number", title: "Suggestions, not answers",
///                             body: "The shortlist can be wrong, including deadly look-alikes."),
///         ]
///     ) { accepted = true }
/// }
/// ```
///
/// Bump the storage key (`_v2`) when the copy changes materially so everyone
/// re-accepts.
public struct DisclaimerView: View {
    private let title: LocalizedStringResource
    private let bodyText: LocalizedStringResource
    private let icon: String?
    private let points: [DisclaimerPoint]
    private let confirmLabel: LocalizedStringResource?
    private let acceptLabel: LocalizedStringResource
    private let onAccept: () -> Void

    @State private var confirmed = false

    /// - Parameters:
    ///   - title: large heading.
    ///   - bodyText: the main explanation.
    ///   - icon: SF Symbol above the title (`nil` for none).
    ///   - points: optional highlighted points under the body.
    ///   - confirmLabel: the "I understand" switch; `nil` enables Continue directly.
    ///   - acceptLabel: the button title (default "Continue").
    ///   - onAccept: persist acceptance and dismiss.
    public init(
        title: LocalizedStringResource,
        bodyText: LocalizedStringResource,
        icon: String? = "exclamationmark.triangle.fill",
        points: [DisclaimerPoint] = [],
        confirmLabel: LocalizedStringResource? = .portfolioKit("I understand"),
        acceptLabel: LocalizedStringResource = .portfolioKit("Continue"),
        onAccept: @escaping () -> Void
    ) {
        self.title = title
        self.bodyText = bodyText
        self.icon = icon
        self.points = points
        self.confirmLabel = confirmLabel
        self.acceptLabel = acceptLabel
        self.onAccept = onAccept
    }

    private var canAccept: Bool { confirmLabel == nil || confirmed }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(bodyText)
                        .font(.body)
                    if !points.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(points.indices, id: \.self) { index in
                                pointRow(points[index])
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }

            Divider()

            VStack(spacing: 12) {
                if let confirmLabel {
                    Toggle(isOn: $confirmed) {
                        Text(confirmLabel).font(.subheadline)
                    }
                    .toggleStyle(.switch)
                }
                Button(action: onAccept) {
                    Text(acceptLabel)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canAccept)
            }
            .padding(24)
        }
    }

    private func pointRow(_ point: DisclaimerPoint) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: point.icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(point.title).font(.headline)
                Text(point.body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
