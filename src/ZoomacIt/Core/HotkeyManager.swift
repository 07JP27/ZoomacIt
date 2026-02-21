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

        // Register ⌃1 (Control + 1, keyCode 0x12 = 18)
        let zoomKeyID = EventHotKeyID(signature: hotKeySignature, id: zoomHotKeyID)
        let zoomStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_1),
            UInt32(controlKey),
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

        NSLog("[HotkeyManager] Global hotkey ⌃1 registered.")

        // Register ⌃2 (Control + 2, keyCode 0x13 = 19)
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: drawHotKeyID)
        let regStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_2),
            UInt32(controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard regStatus == noErr else {
            NSLog("[HotkeyManager] Failed to register hotkey: %d", regStatus)
            stop()
            return
        }

        NSLog("[HotkeyManager] Global hotkey ⌃2 registered.")

        // Register ⌃3 (Control + 3, keyCode 0x14 = 20)
        let breakKeyID = EventHotKeyID(signature: hotKeySignature, id: breakHotKeyID)
        let breakStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_3),
            UInt32(controlKey),
            breakKeyID,
            GetApplicationEventTarget(),
            0,
            &breakHotKeyRef
        )

        guard breakStatus == noErr else {
            NSLog("[HotkeyManager] Failed to register break hotkey: %d", breakStatus)
            return
        }

        NSLog("[HotkeyManager] Global hotkey ⌃3 registered.")
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
