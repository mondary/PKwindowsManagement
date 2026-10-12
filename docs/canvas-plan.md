# Desktop order and horizontal Canvas

Approved scope (2026-10-09):

1. Reorder the active native desktop left/right by dragging its Mission Control
   thumbnail. Preserve desktop identity, contents and focus; verify actual order.
   Status: Dev 2026.10.51, real thumbnail drag pending user validation.
2. An opt-in strip of real windows on the current desktop: next/previous focus,
   comfortable widths, adoption of new windows and restoration on exit.
   Status: redesigned in Dev 2026.10.56 after the Dev 52/54 user tests, on the
   Paneru model (MIT, credited): a scrolling 3×2 grid page on wide displays
   (2×2 on smaller ones) instead of tall columns; Ctrl+Shift+H/L move column by
   column; Option + trackpad/wheel slides the grid; off-viewport columns park
   as edge slivers; exact position+size restoration on exit; a PK snap command
   leaves the Canvas and applies its placement.
3. Modifier + horizontal trackpad/wheel scrolling and independent display strips.
   Status: shipped in Dev 2026.10.56, gated on Option alone (no ⌘/⌃) so apps
   keep their own horizontal scrolling; per-display strips since 2026.10.52.

Native Swift/AppKit and Accessibility. Reuse the existing shortcut/settings
pipeline. Dev-channel delivery and real macOS validation at each milestone.

References: PaperWM.spoon (MIT), Paneru (MIT), ScrollWM (MIT); interaction
inspiration: OnePlus Open Canvas. Implement locally rather than run a second
window manager. Account for macOS off-screen constraints and monitor seams.

Manual validation: reorder A/B/C in both directions with windows on each; verify
Space IDs/order and unchanged membership. Canvas: multiple windows of the same
app, focus via keyboard/click, new/closed windows, modal/fullscreen exclusions,
repeated scrolling, monitor unplugging, Space changes, exact restoration.

Move-focus regression: put competing windows on desktops B/C, then send rapid
right/right/left moves from A. Every move must reference the original window ID,
even if a transition briefly activates a competing window. A click must cancel
old queued moves and let the next request select the clicked window. Close the
retained window: no substitute should move until another user selection.

Canvas regression: navigate all windows in both directions on a single display
and with displays to the left/right/above/below. Each grid row keeps one
baseline; the selected column becomes fully visible; parked slivers stay on
their own display. ⌥ + swipe/wheel slides the grid without stealing plain
scrolling from apps. Exiting restores every window's exact frame — including a
quarter-snapped window — and a snap command during the Canvas leaves the mode
and applies its placement.

Dev 2026.10.66 supersedes the uniform grid and the Dev 63 column pattern:
height is selected PER WINDOW using Ctrl+Shift+F (full) or Ctrl+Shift+S (half).
Adjacent half-height windows are paired without changing strip order. A lone
half retains an empty cell; full-height neighbors are never squeezed into it.
Ctrl+Shift+K/J navigates the two cells. Apps rejecting half height are promoted
to a full-height column. Choices are session-local; new windows start full-height.
Horizontal trackpad scrolling works directly; Option + vertical scroll remains
available for wheels. Automated checks exhaustively cover height combinations
through ten windows, changing height and unpaired halves. Still test live focus,
app minimum sizes, closing/adding windows, restoration and multiple displays.

Dev 2026.10.68 supersedes adjacent-only pairing: `CanvasArrangement` stores
explicit window-ID columns. Selecting any second half-height window places it
below the first, regardless of its original position. Full height splits only
that window; discovery and closure preserve unrelated pairs.

Canvas workspaces are keyed by `(displayID, spaceID)`. Leaving a Space suspends
its strip instead of removing/restoring it. Returning invalidates cached frames
and reapplies the layout with its saved viewport. Unknown Space topology during
Mission Control is also suspension, not removal. Orphaned restore records wait
for their own desktop and do not block commands on other desktops.

Inventory accepts accessory apps, standard AX windows with a nonzero layer and
movable/resizable AXWindow objects with an omitted/unknown subrole. A document
dialog with a minimize button is accepted unless modal. Empty Electron window
inventories use Rooms' temporary AXManualAccessibility initialization, restoring
the original flag immediately afterward. Minimized,
fullscreen, modal/sheet and multi-Space windows remain excluded. The read-only
diagnostic in Windows settings names each visible excluded window by app/ID and
reason, without storing document titles.

Checks: `Tests/CanvasStateChecks.swift` covers all 90 ordered pair choices among
ten windows, splits, discovery and closure, plus active/suspended/disconnected
Space policy; `Tests/CanvasLayoutChecks.swift` retains geometry/monitor checks.
Live Dev 68: settings version verified, Open Rooms → creation → cancel/close
verified via Accessibility; both display choices appear. Canvas diagnostic
returns supported/excluded counts. Real ten-window tiling and scroll after a
Space round trip still require live validation with disposable windows.

User validation on 2026-10-12: scrolling survives a Space round trip in Dev 68.
Remaining reported failure: every second half-height window blinks and is
immediately promoted back to full height. The old placement moved a full-height
window to the bottom before resizing it and classified the immediate AX read as
a size constraint. Dev 69 resizes before moving, repeats after moving, and waits
50/100/200/300 ms on the worker only when size changes. A stable result differing
from the original size is required before learning a minimum; unchanged/rejected
reads retain the requested pairing. Character-grid rounding is retried with a
slightly smaller size to avoid treating a single character row as a minimum.

`CanvasFrameApplicationChecks` covers delayed success, bottom-row write order,
stale original size, unavailable/rejected AX responses, true clamped minimum,
character-grid rounding, position-only scrolling and interruption on Space change.
Those are injected AX responses, not proof of successful placement in every real
app. The two-app bottom-row scenario remains the live acceptance test for Dev 69.

### Dev 70 — activation crash with the app's own settings window

The three user crash reports of 2026-10-12 at 09:29:03, 09:29:11 and 09:29:35
all trap in `NSWMWindowCoordinator.performTransactionUsingBlock` with
`Must only be used from the main thread`. The stack enters AppKit synchronously
from `CanvasWindowAccess.applyCanvasFrame`'s AX size setter on the Canvas queue.
Self-process AX is direct AppKit dispatch, unlike external-process AX messaging.

`CanvasWindowAccess.onAccessibilityThread` now routes individual local AX calls
to main, including reads, setters, window IDs, eligibility and focus actions.
Placement, scroll and journal restoration use the same boundary. External AX,
the negotiation loop and all sleeps stay on the worker; main never waits for
the Canvas queue. The app's own settings window remains eligible.

`Tests/CanvasAccessibilityThreadChecks.swift` checks main-thread reentrancy,
external-call routing, real hidden NSWindow resizing/restoration from the worker,
and a main-loop heartbeat during negotiation waits. The hidden fixture is not
exposed in AXWindows on this machine, so the actual AX branch is explicitly
reported as unavailable; this is not a full-strip GUI acceptance test.
Frame-negotiation checks pass. Dev 70 build, strict signature verification and
local installation pass. The current macOS preferences no longer contain the
previous app-to-agent-Space binding, so live strip activation was not attempted.

### Dev 71 — partial VS Code inventories and Dev publication
The user confirms column splitting works and identifies the omitted windows as
VS Code windows. Neither the Canvas arrangement nor app tiling has a count cap.
The two paths previously used different inventories; tiling read AXWindows only,
while the Canvas initialized Electron AX only when the complete list was empty.
Both now merge AXWindows, direct AXWindow children and main/focused windows,
deduplicate by window ID, and initialize partial inventories when WindowServer
contains missing document-window IDs. A failed second read retains the first.
Canvas also checks actual desktop membership instead of relying solely on the
on-screen flag; hidden apps, minimized windows and foreign Spaces remain excluded.

Tests cover partial 14/24/64-window inventories and pairing/splitting without
losing IDs. These are injected inventory checks, not live VS Code acceptance.
The read-only WindowServer probe found 12 document-sized VS Code windows on Space
632 at that moment; the CLI was not AX-trusted, so the two reported missing
windows could not be conclusively identified. No VS Code preference was changed.

Dev 68–70 had only been installed locally, leaving the public feed at Dev 67.
The manual updater incorrectly treated any differing version as a channel switch.
Dev 71 requires a real Stable/Dev difference to offer a downgrade and compares
the product version before the build timestamp. CI now runs the regression checks,
also triggers on changelog/test changes and serializes Dev publication jobs.

### Dev 72 — 10-of-12 VS Code strip, lost cuts and lag

User reports a stable 10-of-12 window strip, half-height cuts lost on
deactivation, and new lag. Three separate causes:

- Lag: Dev 71 toggled Electron AXManualAccessibility on every 0.8 s observer
  pass whenever the inventory stayed partial. Each switch redraws focus rings.
  `CanvasWindowAccess.windows` now takes `reconcile` (default false); only
  explicit commands (activation, diagnostic, frontmost-app tiling) enable it.
- Discovery cost: SkyLight membership was asked for every window on the system
  per tick. Discovery is now staged — geometry attribution first, SkyLight only
  for non-visible windows already attributed to the display, AX only for apps
  owning candidates. The tick also reuses the existing inventory.
- Missing windows: a restore journal mismatch (character-grid rounding in
  VS Code/terminals) left ghosts that excluded windows as "awaiting Canvas
  restoration". `CanvasFrameApplication.restored()` adopts windows already at
  their journaled frame within rounding tolerance.
- Cuts: `arrangements[workspace]` is kept on toggle-off and reapplied on
  reactivation; closed windows are forgotten by `synchronize`.

Checks: `restored()` adoption/rejection cases, arrangement kept across a
simulated toggle, inventory/state/thread/geometry suites. Injected checks, not
live 12-window VS Code acceptance — that remains the user's test.
