import SwiftUI

/// The system empty-state layout (`ContentUnavailableView`) with an optional
/// primary action — Celiador `DesignKit.EmptyStateView`, genericized.
///
/// ```swift
/// if entries.isEmpty {
///     EmptyStateView(
///         "No catches yet", systemImage: "fish",
///         message: "Log your first catch to see it here.",
///         actionTitle: "Log a Catch"
///     ) { showLogSheet = true }
/// }
/// ```
///
/// Literals are localized from the app's catalog; use the `String` overload for
/// runtime text.
public struct EmptyStateView: View {
    private let title: Text
    private let systemImage: String
    private let message: Text?
    private let actionTitle: Text?
    private let action: (() -> Void)?

    public init(
        _ title: LocalizedStringResource,
        systemImage: String,
        message: LocalizedStringResource? = nil,
        actionTitle: LocalizedStringResource? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: Text(title), systemImage: systemImage,
            message: message.map { Text($0) }, actionTitle: actionTitle.map { Text($0) }, action: action
        )
    }

    /// Verbatim variant for runtime strings.
    @_disfavoredOverload
    public init<S: StringProtocol>(
        _ title: S,
        systemImage: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: Text(verbatim: String(title)), systemImage: systemImage,
            message: message.map { Text(verbatim: $0) }, actionTitle: actionTitle.map { Text(verbatim: $0) },
            action: action
        )
    }

    init(title: Text, systemImage: String, message: Text?, actionTitle: Text?, action: (() -> Void)?) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label { title } icon: { Image(systemName: systemImage) }
        } description: {
            if let message { message }
        } actions: {
            if let actionTitle, let action {
                Button(action: action) { actionTitle }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
