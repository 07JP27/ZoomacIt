import AppKit
import Carbon.HIToolbox

/// Manages global hotkeys using the Carbon RegisterEventHotKey API.
/// Does NOT require Accessibility permission.
final class HotkeyManager: @unchecked Sendable {

    static let shared = HotkeyManager()

    /// Called when the Draw hotkey (⌃2) is triggered.
    var onDrawHotkey: (() -> Void)?

    /// Called when the Still Zoom hotkey (⌃1) is triggered.
    var onZoomHotkey: (() -> Void)?

    /// Called when the Break Timer hotkey (⌃3) is triggered.
    var onBreakHotkey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var zoomHotKeyRef: EventHotKeyRef?
    private var breakHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// Signature used to identify our hot-key events ('ZmIt')
    private let hotKeySignature: OSType = 0x5A6D_4974 // 'ZmIt'
    private let zoomHotKeyID: UInt32 = 0
    private let drawHotKeyID: UInt32 = 1
    private let breakHotKeyID: UInt32 = 2

    private init() {}

    // MARK: - Public

    func start() {
        guard hotKeyRef == nil else {
            NSLog("[HotkeyManager] Hot key already registered — skipping.")
            return
        }

        // Install a Carbon event handler for kEventHotKeyPressed
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard status == noErr else {
            NSLog("[HotkeyManager] Failed to install event handler: %d", status)
            return
        }

        // Register Zoom hotkey
        let zoomKeyID = EventHotKeyID(signature: hotKeySignature, id: zoomHotKeyID)
        let zoomStatus = RegisterEventHotKey(
            Settings.shared.zoomHotkeyKeyCode,
            Settings.shared.zoomHotkeyModifiers,
            zoomKeyID,
            GetApplicationEventTarget(),
            0,
            &zoomHotKeyRef
        )

        guard zoomStatus == noErr else {
            NSLog("[HotkeyManager] Failed to register zoom hotkey: %d", zoomStatus)
            stop()
            return
        }

        NSLog("[HotkeyManager] Zoom hotkey registered: %@",
              Settings.hotkeyDisplayString(keyCode: Settings.shared.zoomHotkeyKeyCode,
                                           modifiers: Settings.shared.zoomHotkeyModifiers))

        // Register Draw hotkey
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: drawHotKeyID)
        let regStatus = RegisterEventHotKey(
            Settings.shared.drawHotkeyKeyCode,
            Settings.shared.drawHotkeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard regStatus == noErr else {
            NSLog("[HotkeyManager] Failed to register draw hotkey: %d", regStatus)
            stop()
            return
        }

        NSLog("[HotkeyManager] Draw hotkey registered: %@",
              Settings.hotkeyDisplayString(keyCode: Settings.shared.drawHotkeyKeyCode,
                                           modifiers: Settings.shared.drawHotkeyModifiers))

        // Register Break Timer hotkey
        let breakKeyID = EventHotKeyID(signature: hotKeySignature, id: breakHotKeyID)
        let breakStatus = RegisterEventHotKey(
            Settings.shared.breakHotkeyKeyCode,
            Settings.shared.breakHotkeyModifiers,
            breakKeyID,
            GetApplicationEventTarget(),
            0,
            &breakHotKeyRef
        )

        guard breakStatus == noErr else {
            NSLog("[HotkeyManager] Failed to register break hotkey: %d", breakStatus)
            return
        }

        NSLog("[HotkeyManager] Break hotkey registered: %@",
              Settings.hotkeyDisplayString(keyCode: Settings.shared.breakHotkeyKeyCode,
                                           modifiers: Settings.shared.breakHotkeyModifiers))
    }

    func stop() {
        if let ref = zoomHotKeyRef {
            UnregisterEventHotKey(ref)
            zoomHotKeyRef = nil
        }
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = breakHotKeyRef {
            UnregisterEventHotKey(ref)
            breakHotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        NSLog("[HotkeyManager] Hotkeys unregistered.")
    }

    /// Re-register all hotkeys with current Settings values.
    func reregisterHotkeys() {
        stop()
        start()
    }

    // MARK: - Event Processing

    fileprivate func handleHotKeyEvent(_ event: EventRef) {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else { return }

        guard hotKeyID.signature == hotKeySignature else { return }

        if hotKeyID.id == zoomHotKeyID {
            DispatchQueue.main.async { [weak self] in
                self?.onZoomHotkey?()
            }
        } else if hotKeyID.id == drawHotKeyID {
            DispatchQueue.main.async { [weak self] in
                self?.onDrawHotkey?()
            }
        } else if hotKeyID.id == breakHotKeyID {
            DispatchQueue.main.async { [weak self] in
                self?.onBreakHotkey?()
            }
        }
    }
}

// MARK: - C Callback

private func hotKeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotKeyEvent(event)

    return noErr
}
