import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ClipboardStore.shared.startMonitoring()

        HotKeyManager.shared.onHotKey = {
            HistoryPanelController.shared.toggle()
        }
        HotKeyManager.shared.register()

        setUpStatusItem()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Clipboard history"
        )

        let menu = NSMenu()

        let showItem = NSMenuItem(
            title: "Show Clipboard History",
            action: #selector(showHistory),
            keyEquivalent: "v"
        )
        showItem.keyEquivalentModifierMask = [.command, .shift]
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(
            title: "Clear History (keeps pinned)",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit MacClipboard",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        item.menu = menu
        statusItem = item
    }

    @objc private func showHistory() {
        HistoryPanelController.shared.show()
    }

    @objc private func clearHistory() {
        ClipboardStore.shared.clearUnpinned()
    }
}
