# Changelog

## [2026.08.06] - 2026-08-03
### Added
- New window actions matching Raycast's window management: Maximize Height/Width, Move Up/Down/Left/Right (to screen edge), Restore, Reasonable Size, Make Larger/Smaller, Toggle Fullscreen, vertical Fourth columns (First/Second/Third/Last), First/Center/Last Two Thirds, First/Center/Last Three Fourths, Top/Bottom Third and Top/Bottom Two Thirds — all with icons and per-language labels
### Changed
- Rebuilt window snapping core around a single AX coordinate space and screen detection by window↔screen intersection (more reliable multi-monitor)
- Left/Right Half cycling (½→⅔→⅓) keeps its 3-second timer, now ignores key autorepeat so holding a shortcut no longer runs away
- Focused-window lookup falls back to Main Window / first window when an app exposes no focused window
- New window actions are unbound by default (bind them in Settings → Windows), like Raycast
### Fixed
- Window management now works with Chrome/Chromium/Electron (the app's accessibility tree is primed via `AXManualAccessibility` + `AXEnhancedUserInterface` before manipulating the window — the same approach Raycast and Rectangle use)
- Holding a shortcut key no longer loops the command (autorepeat is ignored)
- Restore and Toggle Fullscreen remember the window's previous frame
- Window positioning no longer silently fails when accessibility access is missing
- Removed dead `SimpleWindowManager` and unused SVG assets

## [2026.08.05] - 2026-08-03
### Added
- Window snapping service wired to global shortcuts (halves, quarters, thirds, sixths, fullscreen, center, almost-maximize, display cycling)
- Compact shortcut recorder with badge + Record/Stop and clear/reset per row; special keys (arrows, return, tab, space, delete) captured by keycode
- Per-preset margins (general / almost-full / center) as numeric fields, 1% default gap between windows
- True fraction icons for quarters, thirds, and sixths
- Launchpad overlay now shows the app version (bottom-right)
### Changed
- Migrated to CalVer versioning `YYYY.MM.PATCH` (pk-COMMIT convention)
- Default shortcuts: halves `⌃⌥Q/W/E/R`, quarters `⌃⌥Y/P/H/M`, sixths `⌃⌥U/I/O/J/K/L`
- Settings window sidebar toggle moved from system top-right to a left-placed button; custom 2-column layout replaces NavigationSplitView
- Window-shortcuts preferences use a responsive 2-column layout (1 column when narrow)
### Fixed
- Window snapping on external displays no longer jumps back to the MacBook (AX↔NSScreen coordinate flip corrected in screen detection)
- One-time migration resets stale window-shortcut overrides so new defaults apply

## [0.18] - 2026-06-16
### Added
- Menu bar now displays the app's official icon (full color) instead of a generic SF Symbol
- Settings sidebar header shows the official app icon alongside the app name
- Archive snippet available by default for every install, with a dedicated icon and a `Right Command + S` shortcut
- Archive keeps both files on name conflicts (Finder-style `file 2.ext`, `file 3.ext`)
- Archive moves Desktop items to a fast local archive first, then mirrors them to Google Drive in the background (throttled, non-blocking) — no more Mac freeze on large folders
### Changed
- Archive no longer overwrites or prompts on duplicate names
- Archive monthly folders now use deterministic French names (`2026_06_juin`) instead of relying on the process locale
- `DesktopArchive` now points to the Google Drive archive when detected, while keeping the fast local archive as the initial write target
### Fixed
- Duplicate Archive snippets (manual + default) collapsed into a single canonical entry, preserving the existing shortcut

## [0.17] - 2026-06-16
### Added
- Full-screen Big Year view from the menu bar menu
- Desktop app bundle creation documented in the README
### Changed
- Global shortcut startup and refresh now use a lightweight app catalog without loading all app icons
- Dominant icon color is computed only when the Launchpad sort mode is `Icon Color`
### Fixed
- Big Year overlay has safer close paths and less intrusive window behavior
- Timers, event taps, and global handlers are cleaned up more completely on shutdown

## [0.12] - 2026-06-04
### Added
- Left/right modifier key distinction for Command, Option, and Shift in launch shortcuts
- Fn + Shift modifier support for launch shortcuts
- Fine-grained Launchpad grid settings: icon size, column spacing, row spacing
- Top-aligned pages in horizontal navigation mode
- Accessibility status indicator card with grant-access button
- Automatic backup export to a user-chosen folder on every settings change
### Fixed
- Search bar text color now white on dark background in Launchpad overlay

## [0.10] - 2026-06-03
### Added
- Initial project scaffold
