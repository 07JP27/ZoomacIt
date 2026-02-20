import AppKit
import CoreGraphics

/// Checks and requests macOS permissions required by ZoomacIt.
@MainActor
final class PermissionManager {

    static let shared = PermissionManager()

    private init() {}

    // MARK: - Screen Recording

    /// Whether Screen Recording permission has been granted.
    nonisolated var isScreenRecordingGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Request Screen Recording permission.
    func requestScreenRecordingIfNeeded() {
        guard !isScreenRecordingGranted else { return }
        CGRequestScreenCaptureAccess()
    }

    // MARK: - Combined

    /// Request permissions needed for ZoomacIt to function.
    /// Currently only Screen Recording is required (global hotkey uses
    /// Carbon RegisterEventHotKey which does not need Accessibility).
    func requestRequiredPermissions() {
        guard !isScreenRecordingGranted else {
            logPermissionStatus()
            return
        }

        // LSUIElement apps cannot show modal alerts in the foreground.
        // Temporarily switch to a regular app to show the alert,
        // then revert to accessory (menu bar only).
        NSApp.setActivationPolicy(.regular)
        RunLoop.current.run(until: Date())
        NSApp.activate()

        let alert = NSAlert()
        alert.messageText = "ZoomacIt に権限が必要です"
        alert.informativeText = """
        画面キャプチャのために Screen Recording 権限を許可してください。\
        システム設定が開きます。許可後、アプリを再起動してください。

        • Screen Recording（画面キャプチャに必要）
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "後で")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            requestScreenRecordingIfNeeded()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }

        // Revert to accessory (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        logPermissionStatus()
    }

    /// Summary of current permission state.
    func logPermissionStatus() {
        NSLog("[Permissions] Screen Recording: %@", isScreenRecordingGranted ? "✓" : "✗")
    }
}
