import SwiftUI
import Carbon.HIToolbox
import ServiceManagement

/// Hotkey settings tab with key recorder controls.
struct GeneralTab: View {

    @AppStorage(Settings.Keys.zoomHotkeyKeyCode) private var zoomKeyCode: Int = Int(kVK_ANSI_1)
    @AppStorage(Settings.Keys.zoomHotkeyModifiers) private var zoomModifiers: Int = Int(controlKey)
    @AppStorage(Settings.Keys.drawHotkeyKeyCode) private var drawKeyCode: Int = Int(kVK_ANSI_2)
    @AppStorage(Settings.Keys.drawHotkeyModifiers) private var drawModifiers: Int = Int(controlKey)
    @AppStorage(Settings.Keys.breakHotkeyKeyCode) private var breakKeyCode: Int = Int(kVK_ANSI_3)
    @AppStorage(Settings.Keys.breakHotkeyModifiers) private var breakModifiers: Int = Int(controlKey)

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Hotkeys") {
                HotkeyRow(label: "Zoom", keyCode: $zoomKeyCode, modifiers: $zoomModifiers)
                HotkeyRow(label: "Draw", keyCode: $drawKeyCode, modifiers: $drawModifiers)
                HotkeyRow(label: "Break Timer", keyCode: $breakKeyCode, modifiers: $breakModifiers)
            }

            Section {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
            }
        }
        .formStyle(.grouped)
        .onChange(of: zoomKeyCode) { _, _ in reregisterHotkeys() }
        .onChange(of: zoomModifiers) { _, _ in reregisterHotkeys() }
        .onChange(of: drawKeyCode) { _, _ in reregisterHotkeys() }
        .onChange(of: drawModifiers) { _, _ in reregisterHotkeys() }
        .onChange(of: breakKeyCode) { _, _ in reregisterHotkeys() }
        .onChange(of: breakModifiers) { _, _ in reregisterHotkeys() }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    launchAtLogin = newValue
                } catch {
                    NSLog("[GeneralTab] Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
                }
            }
        )
    }

    private func reregisterHotkeys() {
        HotkeyManager.shared.reregisterHotkeys()
        // Notify StatusBarController to update menu hotkey labels
        NotificationCenter.default.post(name: .hotkeysDidChange, object: nil)
    }
}

// MARK: - Hotkey Row

struct HotkeyRow: View {
    let label: String
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)
            Spacer()
            KeyRecorderView(keyCode: $keyCode, modifiers: $modifiers)
                .frame(width: 140, height: 28)
        }
    }
}
