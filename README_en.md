# PKwindowsManagement

[🇬🇧 EN](README_en.md) · [🇫🇷 FR](README.md)

PKwindowsManagement is a macOS menu bar app for keyboard-driven window management. It snaps active windows to halves, thirds, quarters, corners, center, full screen, or another display.

## ✅ Features
- Snap active windows to halves, thirds, quarters, and corners.
- Move a window to the next or previous display.
- Customize keyboard shortcuts from a SwiftUI preferences screen.
- Control the focused window through macOS Accessibility APIs.
- Menu bar icon with quick access to preferences and quit.

## 🧠 Usage
- Launch the app.
- Grant Accessibility permission when macOS asks for it.
- Use the default shortcuts to manage the active window.

### Default shortcuts
- `Ctrl + Option + H` : left half
- `Ctrl + Option + L` : right half
- `Ctrl + Option + K` : top half
- `Ctrl + Option + J` : bottom half
- `Ctrl + Option + M` : maximize
- `Ctrl + Option + C` : center
- `Ctrl + Option + U` : top-left corner
- `Ctrl + Option + I` : top-right corner
- `Ctrl + Option + N` : bottom-left corner
- `Ctrl + Option + O` : bottom-right corner
- `Ctrl + Option + 1` : first third
- `Ctrl + Option + 2` : center third
- `Ctrl + Option + 3` : last third
- `Ctrl + Option + [` : previous display
- `Ctrl + Option + ]` : next display

## ⚙️ Settings
- Shortcuts can be edited in the preferences window.
- Changes are persisted in `UserDefaults`.
- The app also stores the clipboard drawer edge setting.

## 🧾 Commands
- `Open Preferences` : opens the configuration window.
- `Quit` : exits the app.

## 📦 Build & Package
- Requirements: macOS 13 or later.
- Swift tools: 5.10.
- Local build:
```bash
swift build
```
- Local run:
```bash
swift run PKwindowsManagement
```

## 🧪 Install
- Open the project in Xcode or run `swift run PKwindowsManagement`.
- On first launch, grant Accessibility access in `System Settings > Privacy & Security > Accessibility`.
- If the app cannot control windows, check the target app permissions as well.

## 🧾 Changelog
- `0.10` - 2026-06-03
  - Initial project scaffold.

## 🔗 Links
- FR README: [README.md](README.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
