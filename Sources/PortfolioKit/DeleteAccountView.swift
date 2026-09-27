import SwiftUI

/// Copy + friction knobs for ``DeleteAccountView``. Sensible defaults encode the
/// portfolio's gold-standard destructive flow (Nassau + Contrarian): a typed
/// confirmation phrase, a short countdown, and — critically — a reminder that an
/// App Store subscription is **not** cancelled by deleting the account.
///
/// Copy defaults are localized from PortfolioKit's string catalog; string
/// literals you pass are localized from your app's catalog.
public struct DeleteAccountConfig: Sendable {
    public var title: LocalizedStringResource
    public var explanation: LocalizedStringResource
    /// Bulleted list of exactly what will be erased (profile, entries, photos…).
    public var deletedItems: [LocalizedStringResource]
    /// The exact string the user must type to enable deletion. Case-sensitive
    /// and shown verbatim (it is a token, not prose); pass a translated phrase
    /// yourself if you want one per language.
    public var confirmationPhrase: String
    /// Seconds the confirm button stays disabled **after the phrase matches**,
    /// so the action can't be fired reflexively. Editing the phrase so it no
    /// longer matches resets the countdown. Set `0` to disable the countdown.
    public var countdownSeconds: Int
    /// Show the "your App Store subscription won't be cancelled" warning. Set
    /// `false` for apps without paid subscriptions.
    public var warnsAppStoreSubscription: Bool
    public var confirmButtonTitle: LocalizedStringResource

    public init(
        title: LocalizedStringResource = .portfolioKit("Delete Account"),
        explanation: LocalizedStringResource = .portfolioKit("This permanently deletes your account and all associated data. This cannot be undone."),
        deletedItems: [LocalizedStringResource] = [],
        confirmationPhrase: String = "DELETE",
        countdownSeconds: Int = 5,
        warnsAppStoreSubscription: Bool = true,
        confirmButtonTitle: LocalizedStringResource = .portfolioKit("Delete Account")
    ) {
        self.title = title
        self.explanation = explanation
        self.deletedItems = deletedItems
        self.confirmationPhrase = confirmationPhrase
        self.countdownSeconds = countdownSeconds
        self.warnsAppStoreSubscription = warnsAppStoreSubscription
        self.confirmButtonTitle = confirmButtonTitle
    }
}

/// The portfolio's standard account-deletion screen (App Store guideline
/// 5.1.1(v)). Push it from Settings; it collects a typed confirmation, enforces a
/// countdown, warns about the App Store subscription, requires a final dialog, and
/// only then calls the app-supplied `onDelete`. PortfolioKit stays backend-free —
/// the app provides the async deletion work.
public struct DeleteAccountView: View {
    private let config: DeleteAccountConfig
    private let onDelete: @MainActor () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.portfolioSettingsTheme) private var theme

    @State private var typed = ""
    @State private var remaining: Int
    @State private var isDeleting = false
    @State private var showFinalConfirm = false
    /// Bumped only when the final dialog opens, so the warning haptic doesn't
    /// also fire when it is dismissed.
    @State private var finalConfirmHaptic = 0
    @State private var errorMessage: String?

    /// - Parameters:
    ///   - config: copy + friction settings.
    ///   - onDelete: performs the irreversible deletion. Throw to surface an error
    ///     and keep the screen open; return normally to dismiss on success.
    public init(config: DeleteAccountConfig = .init(), onDelete: @escaping @MainActor () async throws -> Void) {
        self.config = config
        self.onDelete = onDelete
        _remaining = State(initialValue: config.countdownSeconds)
    }

    private var gate: DeleteAccountGate {
        DeleteAccountGate(phrase: config.confirmationPhrase, typed: typed, remaining: remaining, isDeleting: isDeleting)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatusCard(
                    title: Text(config.title),
                    detail: Text(config.explanation),
                    icon: "exclamationmark.triangle.fill",
                    tint: .red
                )

                if !config.deletedItems.isEmpty {
                    SettingsSection(LocalizedStringResource.portfolioKit("This will delete")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(config.deletedItems.indices, id: \.self) { index in
                                Label {
                                    Text(config.deletedItems[index])
                                } icon: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                    .foregroundStyle(theme.value)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .settingsRowSurface(theme)
                    }
                }

                if config.warnsAppStoreSubscription {
                    Label {
                        Text(LocalizedStringResource.portfolioKit("Deleting your account does not cancel an App Store subscription. Cancel it separately in Settings ▸ your name ▸ Subscriptions."))
                    } icon: {
                        Image(systemName: "creditcard")
                    }
                    .font(.footnote)
                    .foregroundStyle(theme.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .settingsRowSurface(theme)
                }

                SettingsSection(LocalizedStringResource.portfolioKit("Confirm")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringResource.portfolioKit("Type \(config.confirmationPhrase) to confirm.", comment: "%@ is the confirmation phrase, e.g. DELETE"))
                            .font(.footnote)
                            .foregroundStyle(theme.label)
                        confirmationField
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(role: .destructive) {
                    showFinalConfirm = true
                    finalConfirmHaptic += 1
                } label: {
                    HStack(spacing: 6) {
                        if isDeleting { ProgressView() }
                        Text(config.confirmButtonTitle)
                        if gate.isCountingDown {
                            Text(verbatim: "(\(remaining))").monospacedDigit()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!gate.canDelete)
                .warningHaptic(trigger: finalConfirmHaptic)
            }
            .padding()
        }
        .navigationTitle(Text(config.title))
        .confirmationDialog(
            Text(LocalizedStringResource.portfolioKit("Delete your account? This can't be undone.")),
            isPresented: $showFinalConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) { performDelete() } label: { Text(config.confirmButtonTitle) }
            Button(role: .cancel) {} label: { Text(LocalizedStringResource.portfolioKit("Cancel")) }
        }
        // The countdown starts when the phrase matches (not when the view
        // appears) and restarts if the user edits the phrase away and back.
        .task(id: gate.phraseMatches) {
            remaining = config.countdownSeconds
            guard gate.phraseMatches else { return }
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
            }
        }
    }

    private var confirmationField: some View {
        let field = TextField(config.confirmationPhrase, text: $typed)
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled()
            .settingsRowSurface(theme)
        #if os(iOS) || os(tvOS)
        return field.textInputAutocapitalization(.characters)
        #else
        return field
        #endif
    }

    private func performDelete() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await onDelete()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }
}

/// Pure gating logic for ``DeleteAccountView``, separate from the view so it can
/// be unit-tested.
struct DeleteAccountGate: Equatable {
    var phrase: String
    var typed: String
    /// Seconds left on the post-match countdown.
    var remaining: Int
    var isDeleting: Bool

    var phraseMatches: Bool { typed == phrase }
    var isCountingDown: Bool { phraseMatches && remaining > 0 }
    var canDelete: Bool { phraseMatches && remaining <= 0 && !isDeleting }
}

private extension View {
    /// `.sensoryFeedback` needs visionOS 26, while the package supports
    /// visionOS 1, so it is skipped there (Vision Pro has no haptics anyway).
    @ViewBuilder
    func warningHaptic(trigger: Int) -> some View {
        #if os(visionOS)
        self
        #else
        sensoryFeedback(.warning, trigger: trigger)
        #endif
    }
}
