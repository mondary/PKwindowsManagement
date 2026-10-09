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
