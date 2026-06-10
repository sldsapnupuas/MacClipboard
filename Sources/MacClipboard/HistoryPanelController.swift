import AppKit
import SwiftUI

/// Borderless panel that can still receive key events.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the floating history panel: shows it near the mouse on ⌘⇧V,
/// handles keyboard navigation, and pastes the chosen item into the
/// app that was frontmost when the panel opened.
final class HistoryPanelController: NSObject, NSWindowDelegate {
    static let shared = HistoryPanelController()

    private let store = ClipboardStore.shared
    private let state = PanelState()

    private var panel: NSPanel?
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        state.selectedIndex = 0

        let panel = self.panel ?? makePanel()
        position(panel)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel?.orderOut(nil)
    }

    // MARK: - Panel setup

    private func makePanel() -> NSPanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 440),
            // .nonactivatingPanel keeps the target app active so focus
            // (and the text cursor) stays where the user was typing.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let view = HistoryView(
            store: store,
            state: state,
            onSelect: { [weak self] in self?.paste($0) },
            onDelete: { [weak self] in self?.delete($0) },
            onPin: { [weak self] in self?.store.togglePin($0) },
            onClear: { [weak self] in
                self?.store.clearUnpinned()
                self?.state.selectedIndex = 0
            }
        )
        panel.contentView = NSHostingView(rootView: view)

        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        var origin = NSPoint(x: mouse.x - 20, y: mouse.y - panel.frame.height + 20)
        origin.x = max(visible.minX + 8, min(origin.x, visible.maxX - panel.frame.width - 8))
        origin.y = max(visible.minY + 8, min(origin.y, visible.maxY - panel.frame.height - 8))
        panel.setFrameOrigin(origin)
    }

    // MARK: - Keyboard handling

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isVisible == true else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let count = store.items.count

        switch event.keyCode {
        case 53: // esc
            hide()
            return true
        case 126: // up
            if count > 0 { state.selectedIndex = max(0, state.selectedIndex - 1) }
            return true
        case 125: // down
            if count > 0 { state.selectedIndex = min(count - 1, state.selectedIndex + 1) }
            return true
        case 36, 76: // return / keypad enter
            if store.items.indices.contains(state.selectedIndex) {
                paste(store.items[state.selectedIndex])
            }
            return true
        case 51: // delete (backspace)
            if store.items.indices.contains(state.selectedIndex) {
                delete(store.items[state.selectedIndex])
            }
            return true
        default:
            break
        }

        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }
        if chars == "p" {
            if store.items.indices.contains(state.selectedIndex) {
                store.togglePin(store.items[state.selectedIndex])
            }
            return true
        }
        if let digit = Int(chars), (1...9).contains(digit), store.items.indices.contains(digit - 1) {
            paste(store.items[digit - 1])
            return true
        }
        return false
    }

    // MARK: - Actions

    private func paste(_ item: ClipboardItem) {
        store.copyToPasteboard(item)
        hide()

        previousApp?.activate()
        // Give the target app a beat to become active before the keystroke.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Paster.sendCmdV()
        }
    }

    private func delete(_ item: ClipboardItem) {
        store.remove(item)
        if state.selectedIndex >= store.items.count {
            state.selectedIndex = max(0, store.items.count - 1)
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
