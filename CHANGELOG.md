# Changelog

## [2026.08.08] - 2026-08-04
### Changed
- Restructured the project layout: sources moved to `src/macos/` (room for future `src/linux/`), scripts moved to `src/script/`, build artifacts and packaged app moved from `dist/` + `.build/` into `release/` (via `--scratch-path release/build`)
- Removed the GPL-3 `LaunchNext` reference submodule and the cleanroom note — the app is now 100% independent, no external code references
- `Resources/` root folder (empty localization vestige) removed; real localizations stay in `src/macos/Resources/`
- Scripts now compute the project root two levels up; `.gitignore` updated for `release/`
### Added
- `src/script/`, `src/macos/` directory structure; `src/linux/` placeholder intent
### Removed
- `submodules/LaunchNext`, `CLEANROOM.md`, `Resources/`, `dist/`, `.build/`

## [2026.08.07] - 2026-08-04 🔥
### Fixed
- **Window management now works on Electron apps (Chrome, VS Code, Slack, etc.)** — the root cause was `AXEnhancedUserInterface`: when enabled (default on Electron), these apps silently ignore AX frame changes. Now disabled before setting position/size, re-enabled after
- Window frame is now set in `size → position → size` order (was `position → size`), preventing macOS from rejecting moves when the window is too large for the destination screen
- Focused window lookup now uses `NSWorkspace.frontmostApplication` PID instead of `AXUIElementCreateSystemWide`, with fallback to `kAXWindowsAttribute[0]` — more reliable across all app types
- AX window operations deferred to next run-loop iteration instead of running synchronously inside the CGEvent tap callback (was causing silent failures on non-native apps)
### Changed
- Accessibility section in General settings now has "Re-request Access" and "Open System Settings" buttons for easier permission troubleshooting
### Added
- Localized strings for the new accessibility buttons (fr/de/es)

## [2026.08.06] - 2026-08-03
### Added
- New window actions: Maximize Height/Width, Move Up/Down/Left/Right, Restore, Reasonable Size, Make Larger/Smaller, Toggle Fullscreen, vertical Fourth columns (First/Second/Third/Last), First/Center/Last Two Thirds, First/Center/Last Three Fourths, Top/Bottom Third and Top/Bottom Two Thirds — all with icons and per-language labels
- New window actions are unbound by default (bind them in Settings → Windows)
### Changed
- Snapping core restored to the proven version from 2026.08.05; the new actions are layered additively on top, leaving the original geometry untouched
### Fixed
- Window management no longer broken: the earlier core rewrite made snapping fail for every app — reverted it and re-integrated the new actions additively
- Restore and Toggle Fullscreen remember the window's previous frame
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
