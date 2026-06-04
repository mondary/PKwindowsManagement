# PKwindowsManagement

[🇬🇧 EN](README_en.md) · [🇫🇷 FR](README.md)

PKwindowsManagement is a macOS menu bar app for keyboard-driven window management and fast application launching.

## ✅ Features
- Snap active windows to halves, thirds, quarters, and corners.
- Move a window to the next or previous display.
- Customize keyboard shortcuts from a SwiftUI preferences screen.
- Control the focused window through macOS Accessibility APIs.
- Full-screen Launchpad with search, recent applications, and custom shortcuts.
- Keyboard Launchpad navigation: type to filter, use arrows to select, and press `Enter` to launch.
- Global per-application shortcuts that work anywhere on macOS while Launchpad is closed.
- Left/right modifier key distinction: Command, Option, and Shift (e.g. Right Command + A ≠ Left Command + A).
- `Fn + Shift` modifier support for launch shortcuts.
- Fine-grained Launchpad grid customization: icon size, column spacing, and row spacing.
- Top-aligned pages in horizontal navigation mode.
- Accessibility status indicator with grant-access button.
- Application context menu for assigning shortcuts or moving applications to Trash.
- Open Launchpad with `Option + Space`, the top-left hot corner, or a menu bar icon click.
- Dedicated application icon and context menu for preferences and quit.

## 🧠 Usage
- Launch the app.
- Grant Accessibility permission when macOS asks for it.
- Use the default shortcuts to manage the active window.
- Use `Option + Space` to show or hide Launchpad.
- In Launchpad, start typing and press `Enter` to launch the first result.
- Use arrow keys to change selection.
- Press `Escape` once to clear a search, then again to close Launchpad.
- Click `•••` in the top-right corner to open settings.

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
- Available modifiers: Control+Option, Command, Left/Right Command, Option, Left/Right Option, Shift, Left/Right Shift, Fn+Shift.
- Right-click an application to assign or edit its global shortcut.
- Assigned shortcuts appear as key badges over application icons.
- Launchpad grid customization: columns/rows count, icon size, column and row spacing.
- Changes are persisted in `UserDefaults`.
- Settings import/export in JSON format.

## 🧾 Commands
- Left-click the menu bar icon to open or close Launchpad.
- Right-click the menu bar icon to show `Open Launchpad`, `Open Preferences`, and `Quit`.

## 📦 Build & Package
- Requirements: macOS 13 or later.
- Swift tools: 5.10.
- Local build:
```bash
swift build
```
- Build the debug app bundle and launch it:
```bash
script/build_and_run.sh
```
- Build an app bundle without launching:
```bash
script/package_app.sh debug
script/package_app.sh release
```
- Build a release and copy it to `/Applications`:
```bash
script/release.sh
```

## 🧪 Install
- Run `script/release.sh` to build and install `/Applications/PKwindowsManagement.app`.
- On first launch, grant Accessibility access in `System Settings > Privacy & Security > Accessibility`. This permission is required for window management and global shortcuts.
- If the app cannot control windows, check the target app permissions as well.

## 🧾 Changelog
- `0.11` - 2026-06-04
  - Left/right modifier key distinction for Command, Option, and Shift.
  - Fn + Shift modifier support.
  - Fine-grained grid settings: icon size, column and row spacing.
  - Top-aligned pages in horizontal navigation mode.
  - Accessibility status indicator with grant-access button.
  - Fixed search bar text color (white on dark background).
- `0.10` - 2026-06-03
  - Initial project scaffold.

## 🔗 Links
- FR README: [README.md](README.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
