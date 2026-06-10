# MacClipboard

A macOS clipboard history manager that copies the Windows **Win+V** experience:
press **⌘⇧V** anywhere to open a floating history panel, pick an item, and it
is pasted straight into the app you were using.

## Features

- Clipboard monitoring for **text and images**, with duplicate de-duping
- **⌘⇧V** global hotkey opens the history panel near your mouse
- **Pin** items so they survive "Clear all" and never expire (like Windows)
- Keyboard driven: `↑`/`↓` navigate, `↩` paste, `1–9` quick-paste, `P` pin, `⌫` delete, `esc` close
- Auto-paste into the previously focused app (simulated ⌘V)
- History (up to 50 unpinned items + all pinned) persists across restarts in
  `~/Library/Application Support/MacClipboard/history.json`
- Skips concealed/transient pasteboard content (e.g. password managers that mark it)
- Menu bar icon with show/clear/quit

## Build & run

```sh
./build-app.sh
open MacClipboard.app
```

For development you can also run it directly with `swift run`.

## Permissions

The hotkey and history work with no special permissions. **Auto-paste** needs
Accessibility access: the first time you select an item, macOS prompts you —
enable *MacClipboard* under **System Settings → Privacy & Security →
Accessibility**, then try again. Until then, selecting an item still copies it;
just press ⌘V yourself.

## Start at login

System Settings → General → Login Items → add `MacClipboard.app`.

## Notes / limitations

- macOS has no clipboard-change notification API, so the app polls the
  pasteboard every 0.4 s (this is what every clipboard manager does).
- Files copied in Finder are recorded as text paths only if the app puts a
  string on the pasteboard; rich-text formatting is stored as plain text.
- Images larger than 10 MB are not kept in history.
