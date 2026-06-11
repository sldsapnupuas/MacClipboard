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
    private var keyTap: CFMachPort?
    private var keyTapSource: CFRunLoopSource?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
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
        // Show without taking key focus: stealing it makes Spotlight's search
        // field lose its cursor and confuses focus under Stage Manager. Keys
        // arrive via a CGEvent tap instead. If the tap can't be created (no
        // Accessibility permission yet), fall back to becoming key.
        if installKeyTap() {
            panel.orderFrontRegardless()
        } else {
            panel.makeKeyAndOrderFront(nil)
            installKeyMonitor()
        }
        installClickMonitor()
    }

    func hide() {
        removeKeyTap()
        removeKeyMonitor()
        removeClickMonitor()
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
        panel.becomesKeyOnlyIfNeeded = true
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

    /// Intercepts key-downs system-wide while the panel is visible, so the
    /// panel can be navigated without ever being the key window. Returns
    /// false if the tap couldn't be created (Accessibility not granted).
    private func installKeyTap() -> Bool {
        removeKeyTap()

        let callback: CGEventTapCallBack = { _, type, cgEvent, userInfo in
            let passthrough = Unmanaged.passUnretained(cgEvent)
            guard let userInfo else { return passthrough }
            let controller = Unmanaged<HistoryPanelController>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.keyTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return passthrough
            }
            guard controller.panel?.isVisible == true,
                  let event = NSEvent(cgEvent: cgEvent) else { return passthrough }
            return controller.handle(event) ? nil : passthrough
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        keyTap = tap
        keyTapSource = source
        return true
    }

    private func removeKeyTap() {
        guard let keyTap else { return }
        CGEvent.tapEnable(tap: keyTap, enable: false)
        if let keyTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), keyTapSource, .commonModes)
        }
        self.keyTap = nil
        keyTapSource = nil
    }

    /// Global monitors only see events in other apps, so clicks on the
    /// panel itself don't dismiss it.
    private func installClickMonitor() {
        removeClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }

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

        // The panel never took key focus, so the target app normally still
        // has it. Only re-activate if something else took over — re-asserting
        // focus dismisses transient overlays like Spotlight.
        let frontmost = NSWorkspace.shared.frontmostApplication
        if let previousApp,
           previousApp.processIdentifier != frontmost?.processIdentifier {
            previousApp.activate()
            // Give the target app a beat to become active before the keystroke.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                Paster.sendCmdV()
            }
        } else {
            // Next runloop pass, so the keystroke isn't posted from inside
            // the event-tap callback that delivered the selection key.
            DispatchQueue.main.async {
                Paster.sendCmdV()
            }
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
