import SwiftUI

private struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let icon: String?
    let tint: Color
    let duration: Duration

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    HStack(spacing: 8) {
                        if let icon {
                            Image(systemName: icon)
                                .foregroundStyle(tint)
                                .accessibilityHidden(true)
                        }
                        Text(verbatim: message)
                            .font(.subheadline.weight(.medium))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.08)))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isStaticText)
                    .onTapGesture { self.message = nil }
                    .task(id: message) {
                        AccessibilityNotification.Announcement(message).post()
                        try? await Task.sleep(for: duration)
                        guard !Task.isCancelled else { return }
                        self.message = nil
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: message)
    }
}

public extension View {
    /// A transient bottom toast (Celiador `DesignKit`). Set `message` to show it;
    /// it dismisses itself after `duration` (or on tap) by setting the binding
    /// back to `nil`, and is announced to VoiceOver.
    ///
    /// ```swift
    /// @State private var toast: String?
    /// …
    /// .toast($toast)
    /// .toast($error, icon: "exclamationmark.triangle.fill", tint: .orange)
    ///
    /// toast = String(localized: "Copied to clipboard")
    /// ```
    ///
    /// The message is shown verbatim — localize it before assigning.
    func toast(
        _ message: Binding<String?>,
        icon: String? = "checkmark.circle.fill",
        tint: Color = .accentColor,
        duration: Duration = .seconds(2.4)
    ) -> some View {
        modifier(ToastModifier(message: message, icon: icon, tint: tint, duration: duration))
    }
}
