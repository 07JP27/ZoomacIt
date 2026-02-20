import AppKit

@MainActor
final class StatusBarController: NSObject {

    private var statusItem: NSStatusItem?

    override init() {
        super.init()
        setupStatusItem()
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

        let drawItem = NSMenuItem(title: "Draw", action: #selector(drawAction), keyEquivalent: "2")
        drawItem.keyEquivalentModifierMask = [.control]
        drawItem.target = self
        menu.addItem(drawItem)

        let breakItem = NSMenuItem(title: "Break", action: #selector(breakAction), keyEquivalent: "3")
        breakItem.keyEquivalentModifierMask = [.control]
        breakItem.target = self
        menu.addItem(breakItem)

        menu.addItem(.separator())

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

    @objc private func drawAction() {
        HotkeyManager.shared.onDrawHotkey?()
    }

    @objc private func breakAction() {
        HotkeyManager.shared.onBreakHotkey?()
    }

    @objc private func aboutAction() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
