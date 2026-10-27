import SwiftUI
#if os(iOS) || os(visionOS)
import UIKit
#endif

/// Where "Open Settings" goes for the current platform.
public enum AppSettingsLink {
    /// The app's page in Settings (iOS/visionOS), the Privacy & Security pane
    /// (macOS), or `nil` where apps can't deep-link into Settings (watchOS).
    @MainActor
    public static var url: URL? {
        #if os(iOS) || os(visionOS)
        URL(string: UIApplication.openSettingsURLString)
        #elseif os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")
        #else
        nil
        #endif
    }
}

private struct PermissionDeniedAlert: ViewModifier {
    @Environment(\.openURL) private var openURL
    @Binding var isPresented: Bool
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    func body(content: Content) -> some View {
        content.alert(Text(title), isPresented: $isPresented) {
            if let url = AppSettingsLink.url {
                Button {
                    openURL(url)
                } label: {
                    Text(LocalizedStringResource.portfolioKit("Open Settings"))
                }
                Button(role: .cancel) {} label: {
                    Text(LocalizedStringResource.portfolioKit("Not Now"))
                }
            } else {
                Button(role: .cancel) {} label: {
                    Text(LocalizedStringResource.portfolioKit("OK"))
                }
            }
        } message: {
            Text(message)
        }
    }
}

public extension View {
    /// The standard "permission is off — Open Settings" alert, for when a
    /// camera/location/notification/microphone request was previously denied
    /// and the system won't ask again (ThenCam, Lunker, Sextant patterns).
    ///
    /// ```swift
    /// .permissionDeniedAlert(
    ///     isPresented: $showCameraDenied,
    ///     title: "Camera Access Is Off",
    ///     message: "Allow camera access in Settings to scan labels."
    /// )
    /// ```
    ///
    /// On watchOS (no Settings deep link) it shows an OK button only.
    func permissionDeniedAlert(
        isPresented: Binding<Bool>,
        title: LocalizedStringResource,
        message: LocalizedStringResource
    ) -> some View {
        modifier(PermissionDeniedAlert(isPresented: isPresented, title: title, message: message))
    }
}
