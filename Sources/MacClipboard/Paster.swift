import AppKit
import ApplicationServices

/// Simulates ⌘V in the frontmost app. Requires Accessibility permission;
/// without it the selected item is still on the clipboard, the user just
/// pastes manually.
enum Paster {
    /// Returns true if the synthetic keystroke was sent.
    @discardableResult
    static func sendCmdV() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return false }

        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true), // 9 = V
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
