import AppKit
import AudioToolbox
import ScreenCaptureKit

/// Manages the lifecycle of the Break Timer overlay window.
@MainActor
final class BreakTimerWindowController {

    private var timerWindow: BreakTimerWindow?
    private var timerView: BreakTimerView?
    private var countdownTimer: Timer?
    private var state: BreakTimerState
    private var playingSound: NSSound?  // retain while playing

    /// Sound used for test playback from Settings. Static so it can be stopped.
    private static var testSound: NSSound?

    /// Whether a test sound is currently playing.
    static var isTestSoundPlaying: Bool {
        testSound?.isPlaying ?? false
    }

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
        state.reloadFromSettings()
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

        countdownTimer?.invalidate()
        countdownTimer = nil

        // Stop any expiration sound still playing
        playingSound?.stop()
        playingSound = nil

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
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let justExpired = self.state.tick()

            if justExpired {
                NSLog("[BreakTimerController] Timer expired!")
                self.playExpirationSound()
            }

            self.timerView?.needsDisplay = true
        }
        NSLog("[BreakTimerController] Countdown started.")
    }

    private func playExpirationSound() {
        guard state.playSoundOnExpiration else {
            NSLog("[BreakTimerController] Sound disabled, skipping.")
            return
        }
        if let url = state.soundFileURL {
            if let sound = NSSound(contentsOf: url, byReference: true) {
                playingSound = sound
                sound.play()
                NSLog("[BreakTimerController] Playing custom sound from %@.", url.lastPathComponent)
            } else {
                NSLog("[BreakTimerController] Failed to load sound from %@, playing default.", url.absoluteString)
                Self.playDefaultSound()
            }
        } else {
            Self.playDefaultSound()
        }
    }

    /// Play a test sound from Settings. Stops any previously playing test sound first.
    static func playTestSound(fileURL: URL?) {
        stopTestSound()
        if let url = fileURL {
            if let sound = NSSound(contentsOf: url, byReference: true) {
                testSound = sound
                sound.play()
                NSLog("[BreakTimerController] Test: playing custom sound from %@.", url.lastPathComponent)
            } else {
                NSLog("[BreakTimerController] Test: failed to load sound from %@, playing default.", url.absoluteString)
                playDefaultSound()
            }
        } else {
            playDefaultSound()
        }
    }

    /// Stop the currently playing test sound.
    static func stopTestSound() {
        testSound?.stop()
        testSound = nil
    }

    /// Play the default expiration alert sound.
    private static func playDefaultSound() {
        // Try named system sounds first (more reliable than NSSound.beep / AudioServices)
        if let glass = NSSound(named: "Glass") {
            glass.play()
        } else {
            AudioServicesPlayAlertSound(kSystemSoundID_UserPreferredAlert)
        }
        NSLog("[BreakTimerController] Playing default alert sound.")
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
