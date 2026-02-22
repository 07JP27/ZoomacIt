import AppKit
import Carbon.HIToolbox

@MainActor
final class StatusBarController: NSObject {

    private var statusItem: NSStatusItem?
    var onPreferences: (() -> Void)?

    override init() {
        super.init()
        setupStatusItem()
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsDidReset),
            name: .settingsDidReset, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(hotkeysDidChange),
            name: .hotkeysDidChange, object: nil
        )
    }

    @objc private func settingsDidReset() {
        rebuildMenu()
    }

    @objc private func hotkeysDidChange() {
        rebuildMenu()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        NSLog("[StatusBar] statusItem created: %@", statusItem != nil ? "yes" : "no")

        guard let button = statusItem?.button else {
            NSLog("[StatusBar] ERROR: button is nil")
            return
        }

        // Use custom menu bar icon from asset catalog
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            button.image = image
            NSLog("[StatusBar] Icon set successfully")
        } else {
            // Fallback: use SF Symbol
            if let sfImage = NSImage(systemSymbolName: "pencil.and.outline",
                                     accessibilityDescription: "ZoomacIt") {
                sfImage.isTemplate = true
                button.image = sfImage
            } else {
                button.title = "Z"
            }
            NSLog("[StatusBar] Custom icon not found, using fallback")
        }

        statusItem?.menu = buildMenu()
        NSLog("[StatusBar] Menu assigned")
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let s = Settings.shared

        let zoomItem = NSMenuItem(title: "Zoom", action: #selector(zoomAction),
                                  keyEquivalent: Settings.keyCodeToMenuCharacter(s.zoomHotkeyKeyCode))
        zoomItem.keyEquivalentModifierMask = Settings.carbonToNSEventModifiers(s.zoomHotkeyModifiers)
        zoomItem.target = self
        menu.addItem(zoomItem)

        let drawItem = NSMenuItem(title: "Draw", action: #selector(drawAction),
                                  keyEquivalent: Settings.keyCodeToMenuCharacter(s.drawHotkeyKeyCode))
        drawItem.keyEquivalentModifierMask = Settings.carbonToNSEventModifiers(s.drawHotkeyModifiers)
        drawItem.target = self
        menu.addItem(drawItem)

        let breakItem = NSMenuItem(title: "Break", action: #selector(breakAction),
                                   keyEquivalent: Settings.keyCodeToMenuCharacter(s.breakHotkeyKeyCode))
        breakItem.keyEquivalentModifierMask = Settings.carbonToNSEventModifiers(s.breakHotkeyModifiers)
        breakItem.target = self
        menu.addItem(breakItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(preferencesAction), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = [.command]
        prefsItem.target = self
        menu.addItem(prefsItem)

        let aboutItem = NSMenuItem(title: "About ZoomacIt", action: #selector(aboutAction), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit ZoomacIt", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func zoomAction() {
        HotkeyManager.shared.onZoomHotkey?()
    }

    @objc private func drawAction() {
        HotkeyManager.shared.onDrawHotkey?()
    }

    @objc private func breakAction() {
        HotkeyManager.shared.onBreakHotkey?()
    }

    @objc private func preferencesAction() {
        onPreferences?()
    }

    @objc private func aboutAction() {
        let credits = NSAttributedString(
            string: "https://github.com/07JP27/ZoomacIt",
            attributes: [
                .link: URL(string: "https://github.com/07JP27/ZoomacIt")!,
                .font: NSFont.systemFont(ofSize: 11)
            ]
        )
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .init(rawValue: "Copyright"): "© 2026 07JP27"
        ])
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }

    /// Rebuild the menu to reflect updated hotkey settings.
    func rebuildMenu() {
        statusItem?.menu = buildMenu()
    }
}
