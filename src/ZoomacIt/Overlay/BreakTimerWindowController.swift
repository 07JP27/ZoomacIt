import AppKit
import ScreenCaptureKit

/// Manages the lifecycle of the Break Timer overlay window.
@MainActor
final class BreakTimerWindowController {

    private var timerWindow: BreakTimerWindow?
    private var timerView: BreakTimerView?
    private var timerSource: DispatchSourceTimer?
    private var state: BreakTimerState

    /// True while the timer is visible.
    var isActive: Bool { timerWindow != nil }

    init() {
        self.state = BreakTimerState()
    }

    // MARK: - Public

    func showTimer() {
        guard let screen = NSScreen.main else {
            NSLog("[BreakTimerController] No main screen available.")
            return
        }

        NSLog("[BreakTimerController] Starting break timer: %d seconds", state.defaultDuration)
        state.remainingSeconds = state.defaultDuration
        state.elapsedSinceExpiration = 0

        if state.background == .fadedDesktop {
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
            let scaleFactor = screen.backingScaleFactor
            let screenFrame = screen.frame

            Task { @MainActor in
                let captured = await Self.captureScreenImage(
                    displayID: screenNumber,
                    width: screenFrame.width,
                    height: screenFrame.height,
                    scaleFactor: scaleFactor
                )
                self.presentTimer(screen: screen, capturedImage: captured)
            }
        } else {
            presentTimer(screen: screen, capturedImage: nil)
        }
    }

    func dismiss() {
        NSLog("[BreakTimerController] Dismissing break timer.")

        timerSource?.cancel()
        timerSource = nil

        timerWindow?.orderOut(nil)
        timerWindow?.close()
        timerWindow = nil
        timerView = nil

        // Notify the app delegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.breakTimerDidEnd()
        }
    }

    /// Bring the timer window back to the foreground (e.g. from menu bar click).
    func bringToFront() {
        timerWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    // MARK: - Private

    private func presentTimer(screen: NSScreen, capturedImage: CGImage?) {
        let window = BreakTimerWindow(for: screen)
        let view = BreakTimerView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            state: state,
            capturedImage: capturedImage
        )
        view.onDismiss = { [weak self] in
            self?.dismiss()
        }

        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        NSApplication.shared.activate(ignoringOtherApps: true)

        timerWindow = window
        timerView = view

        startCountdown()
    }

    private func startCountdown() {
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let justExpired = self.state.tick()

            if justExpired {
                NSLog("[BreakTimerController] Timer expired!")
                self.playExpirationSound()
            }

            self.timerView?.needsDisplay = true
        }
        source.resume()
        timerSource = source
        NSLog("[BreakTimerController] Countdown started.")
    }

    private func playExpirationSound() {
        guard state.playSoundOnExpiration else { return }

        if let url = state.soundFileURL {
            if let sound = NSSound(contentsOf: url, byReference: true) {
                sound.play()
                NSLog("[BreakTimerController] Playing custom expiration sound.")
            }
        } else {
            NSSound.beep()
            NSLog("[BreakTimerController] Playing system beep.")
        }
    }

    // MARK: - Screen Capture

    private static func captureScreenImage(
        displayID: CGDirectDisplayID,
        width: CGFloat,
        height: CGFloat,
        scaleFactor: CGFloat
    ) async -> CGImage? {
        guard CGPreflightScreenCaptureAccess() else {
            NSLog("[BreakTimerController] Screen Recording not permitted — using black background.")
            return nil
        }

        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = availableContent.displays.first(where: { $0.displayID == displayID }) else {
                NSLog("[BreakTimerController] Display not found.")
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(width * scaleFactor)
            config.height = Int(height * scaleFactor)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            NSLog("[BreakTimerController] Screen capture failed: %@", error.localizedDescription)
            return nil
        }
    }
}
