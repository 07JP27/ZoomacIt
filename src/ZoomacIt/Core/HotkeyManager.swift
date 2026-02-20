import AppKit
import Carbon.HIToolbox

/// Manages global hotkeys using the Carbon RegisterEventHotKey API.
/// Does NOT require Accessibility permission.
final class HotkeyManager: @unchecked Sendable {

    static let shared = HotkeyManager()

    /// Called when the Draw hotkey (⌃2) is triggered.
    var onDrawHotkey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// Signature used to identify our hot-key events ('ZmIt')
    private let hotKeySignature: OSType = 0x5A6D_4974 // 'ZmIt'
    private let drawHotKeyID: UInt32 = 1

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
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        NSLog("[HotkeyManager] Hotkey unregistered.")
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

        if hotKeyID.signature == hotKeySignature && hotKeyID.id == drawHotKeyID {
            DispatchQueue.main.async { [weak self] in
                self?.onDrawHotkey?()
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
