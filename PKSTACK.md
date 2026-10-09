# PKSTACK

Skills used for this project:

- `macos-patterns` — native app, Accessibility, display geometry, wallpaper assignment, settings persistence, and global shortcuts.
- `macos-settings-ui` — macOS settings pane labels and update-version comparison layout.
- `macos-build` — SwiftPM build verification with the explicit macOS 26.5 SDK; private Spaces actions remain runtime-unverified.
- Spaces bridge QA — read-only runtime probe validates the local Mach-O symbol against SkyLight with `dladdr`, plus missing-symbol/image cases; actual moves remain user-tested on Dev.
- Focus/Canvas regression QA — `WindowMoveSequenceChecks` covers rapid queued moves and click cancellation; `CanvasLayoutChecks` covers constant titlebar alignment and selected-window visibility across monitor topologies. Dev 52 user test failed; Dev 54 runtime retest pending (app not assigned to the dedicated agent Space; Dev 53 CI compiler compatibility fixed in 54).
- `app-presence-sync` — README FR/EN and local landing download link match the latest verified Stable; defer hub/FTP publication until the Dev UI has been tested.
- `premium-promo-media` — audited the existing landing/media pipeline; defer feature claims, refreshed captures, hub, and FTP until a Dev build can be tested.
- `macos-menu-and-settings` — menu-bar action placement and aligned icons.
- `pk-settings-shell` — Shared settings shell; Credits uses official project icons and full-row links, with one persistent footer across every settings page.
- `pk-commits` — CalVer bump, changelog, commit and Dev-channel publication workflow.
- `pk-app-release` — Stable release version/tag, GitHub assets, Homebrew cask and Sparkle checklist.
- `publish-macos-sparkle` — Validate the signed Stable archive and generated appcast workflow.
- `sparkle-github-updates` — Diagnosed Dev update shutdown deadlock using a live process sample. AppKit termination fixture reproduces the old hang; installer tests verify process-exit gating and rollback without opening user apps.
