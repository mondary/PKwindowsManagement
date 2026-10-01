# Native Store Captures

Run from the repository root on macOS with Xcode Command Line Tools installed:

```sh
ruby store/tools/capture.rb
```

Allow several minutes for Swift compilation. Outputs are real 1600 x 1000 PNGs:

- `store/screenshots/launchpad.png`: `LaunchpadOverlayRootView`, including the actual `LaunchpadOverlayView`, its native gradient, controls, shortcut badges, app grid and dock.
- `store/screenshots/big-year.png`: `BigYearRootView` from `Views/BigYear/BigYearView.swift`, year 2026, default pastel theme, four invented birthdays and six invented plans.

## Native Search GIF

```sh
ruby store/tools/capture.rb --search
```

Requires macOS 13+ and `ffmpeg` with libx264 in addition to the Swift compiler. Allow up to several minutes for compilation. This mode never writes to `store/screenshots` and verifies every existing PNG there, including `launchpad.png` and `big-year.png`, by SHA-256. It leaves `demo.mp4` and `shotcraft.mp4` untouched.

Outputs under `store/videos`:

- `launchpad-search.gif`: looping 8-second animation, 900 x 562, 120 frames, approximately 181 KB in the verified run.
- `launchpad-search.mp4`: H.264 companion, same dimensions and timeline.
- `launchpad-search-poster.png`: native `cal` state, frame 50.
- `launchpad-search-contact.png`: seven captured states in reading order; eighth cell intentionally empty.
- `launchpad-search-evidence.json`: frame indices, query values and locally recognized native grid labels.

The single mounted production `LaunchpadOverlayRootView` stays alive for the sequence `empty -> c -> ca -> cal -> ca -> c -> empty`. The harness finds its actual editable `NSTextField`, sets `stringValue`, and posts `NSControl.textDidChangeNotification` to that field. This invokes the existing SwiftUI editing/binding path and updates the real private query state, filtering and selection. No query initializer, replacement view, patched UI source, fabricated results or screenshot camera animation is used. This is programmatic native text editing, not physical keyboard-event or foreground-focus testing. No Return, Escape, clicks, global events, app launches or destructive actions are dispatched.

Each image is freshly captured with `cacheDisplay`; output timing is controlled at 15 fps rather than a measurement of wall-clock interaction latency. Holds are 1.6 / 0.8 / 0.8 / 2.4 / 0.4 / 0.4 / 1.6 seconds. `c` legitimately retains the Apple apps because their bundle identifiers contain `com`; `ca` yields Calculator, Calendar and Podcasts; `cal` yields Calculator and Calendar.

An unordered SwiftUI host exposes no usable accessibility children here, so Apple Vision OCR checks the rendered grid pixels locally, excluding the search field and dock. Assertions require Calendar and Calculator for `cal`, Weather disappearing, and the original recognized labels returning after reset. The evidence preserves raw OCR, including occasional recognition errors in unrelated labels. Every captured frame also asserts the window remains invisible/non-key and the harness application inactive. The completed contact sheet was visually inspected and `ffprobe` verified 120 GIF frames and exactly 8 seconds.

Encoding is reproducible in `capture.rb`: Lanczos downscale, `palettegen=stats_mode=diff`, then `paletteuse=dither=sierra2_4a:diff_mode=rectangle`, infinite GIF loop. Full-resolution 1600 x 1000 source frames and the palette remain in the temporary build directory printed by the command. The verified run used `/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode/pk-store-capture-20260908-10030-zt85s4/search-frames`.

The top/dock crop persists even without a fixed SwiftUI root frame and with hosting sizing options disabled. It is not a simple mounting-size problem: `gridMetrics` reserves height minus 260, while the horizontal-page stack's other controls, padding and gaps need about 334 points. Increasing host height does not remove that approximately 74-point overflow. No production layout change or pixel reconstruction was made; existing stills remain unchanged. Hidden-window rendering also does not reproduce an active window's normal caret/focus appearance.

## Provenance And Safety

The script assembles Swift sources automatically, excluding the production `@main` and `MenuBarController`. All other app sources are compiled directly, except `AppLauncherService.swift`: a temporary copy gets the same-file extension in `CatalogFixture.swift` to seed its private installed-app cache. No UI code is replaced or drawn by the harness.

The catalog contains only 19 explicitly allowlisted Apple application bundles. Icons come from those bundles through `NSWorkspace`; no application directory scan, user snippets, recent history or personal app names are needed. The real built-in Empty Trash and Eject tiles remain visible; nothing is clicked or launched.

Each run creates an app bundle with a fresh UUID identifier. `AppSettings(defaults:)` receives a separate fresh UUID suite; its snippet migrations are disabled and its snippet list is empty. Backups and system-calendar access are disabled before settings initialization. The production defaults domain is never opened or changed. Only the harness's own defaults domains are removed at exit. Localization uses launch arguments in the isolated process.

Rendering uses `NSHostingView.cacheDisplay` in an unordered, non-key `NSWindow`, with application activation prohibited. This supports the real AppKit-backed text field and SwiftUI lifecycle/catalog loading without Computer Use, screen recording, focus changes or clipboard access. A standalone `ImageRenderer` would not provide that mounted lifecycle and native representable capture.

Builds, module caches, the generated service source and the executable remain under `/var/folders/jb/07k9zyks6_d60c27tclhjd2h0000gn/T/opencode/pk-store-capture-*`, never in the repository. The script verifies SHA-256 fingerprints of `src` and the existing `appearance.png`/`shortcuts.png` before and after execution. Runtime assertions check settings isolation, fixture counts and PNG dimensions.

The images were visually inspected after capture. Native layout is deliberately unchanged: the fullscreen launchpad's current fixed-height layout slightly crops its top control and dock at this viewport. Big Year's current-day marker and the Calendar app icon depend on the capture date; school vacations use the app's existing public-data loader, so reruns are not byte-identical. No pixel retouching or fabricated controls are applied.
