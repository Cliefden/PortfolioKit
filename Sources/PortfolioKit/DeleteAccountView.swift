import SwiftUI

/// Copy + friction knobs for ``DeleteAccountView``. Sensible defaults encode the
/// portfolio's gold-standard destructive flow (Nassau + Contrarian): a typed
/// confirmation phrase, a short countdown, and — critically — a reminder that an
/// App Store subscription is **not** cancelled by deleting the account.
public struct DeleteAccountConfig: Sendable {
    public var title: String
    public var explanation: String
    /// Bulleted list of exactly what will be erased (profile, entries, photos…).
    public var deletedItems: [String]
    /// The exact string the user must type to enable deletion. Case-sensitive.
    public var confirmationPhrase: String
    /// Seconds the confirm button stays disabled after the phrase matches, so the
    /// action can't be fired reflexively. Set `0` to disable the countdown.
    public var countdownSeconds: Int
    /// Show the "your App Store subscription won't be cancelled" warning. Set
    /// `false` for apps without paid subscriptions.
    public var warnsAppStoreSubscription: Bool
    public var confirmButtonTitle: String

    public init(
        title: String = "Delete Account",
        explanation: String = "This permanently deletes your account and all associated data. This cannot be undone.",
        deletedItems: [String] = [],
        confirmationPhrase: String = "DELETE",
        countdownSeconds: Int = 5,
        warnsAppStoreSubscription: Bool = true,
        confirmButtonTitle: String = "Delete Account"
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
    private let onDelete: () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.portfolioSettingsTheme) private var theme

    @State private var typed = ""
    @State private var remaining: Int
    @State private var isDeleting = false
    @State private var showFinalConfirm = false
    @State private var errorMessage: String?

    /// - Parameters:
    ///   - config: copy + friction settings.
    ///   - onDelete: performs the irreversible deletion. Throw to surface an error
    ///     and keep the screen open; return normally to dismiss on success.
    public init(config: DeleteAccountConfig = .init(), onDelete: @escaping () async throws -> Void) {
        self.config = config
        self.onDelete = onDelete
        _remaining = State(initialValue: config.countdownSeconds)
    }

    private var phraseMatches: Bool { typed == config.confirmationPhrase }
    private var canDelete: Bool { phraseMatches && remaining == 0 && !isDeleting }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StatusCard(
                    title: config.title,
                    detail: config.explanation,
                    icon: "exclamationmark.triangle.fill",
                    tint: .red
                )

                if !config.deletedItems.isEmpty {
                    SettingsSection("This will delete") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(config.deletedItems, id: \.self) { item in
                                Label(item, systemImage: "xmark.circle.fill")
                                    .foregroundStyle(theme.value)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .settingsRowSurface(theme)
                    }
                }

                if config.warnsAppStoreSubscription {
                    Label(
                        "Deleting your account does not cancel an App Store subscription. Cancel it separately in Settings ▸ your name ▸ Subscriptions.",
                        systemImage: "creditcard"
                    )
                    .font(.footnote)
                    .foregroundStyle(theme.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .settingsRowSurface(theme)
                }

                SettingsSection("Confirm") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type \(config.confirmationPhrase) to confirm.")
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
                } label: {
                    HStack(spacing: 6) {
                        if isDeleting { ProgressView() }
                        Text(deleteButtonTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!canDelete)
                .sensoryFeedback(.warning, trigger: showFinalConfirm)
            }
            .padding()
        }
        .navigationTitle(config.title)
        .confirmationDialog(
            "Delete your account? This can't be undone.",
            isPresented: $showFinalConfirm,
            titleVisibility: .visible
        ) {
            Button(config.confirmButtonTitle, role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            guard config.countdownSeconds > 0 else { return }
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

    private var deleteButtonTitle: String {
        if phraseMatches && remaining > 0 { return "\(config.confirmButtonTitle) (\(remaining))" }
        return config.confirmButtonTitle
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
