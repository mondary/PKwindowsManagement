# Desktop order and horizontal Canvas

Approved scope (2026-10-09):

1. Reorder the active native desktop left/right by dragging its Mission Control
   thumbnail. Preserve desktop identity, contents and focus; verify actual order.
   Status: Dev 2026.10.51, real thumbnail drag pending user validation.
2. An opt-in strip of real windows on the current desktop: next/previous focus,
   comfortable widths, adoption of new windows and restoration on exit.
    Status: Dev 2026.10.52 user test reported vertical waves and unstable focus.
    Dev 2026.10.54 (53 CI build failed) removes vertical parking, measures accepted widths before
    placement, and retains selection during keyboard navigation. Runtime retest
    pending; restoration remains best-effort with a persistent retry journal.
    Modifier + horizontal scrolling is milestone 3.
3. Modifier + horizontal trackpad/wheel scrolling and independent display strips.
   Status: per-display strips shipped in Dev 2026.10.52; scrolling pending.

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
and with displays to the left/right/above/below. Every titlebar stays at the
same Y. The selected window is fully revealed (except an app whose minimum
width exceeds the screen). At seams, native windows stack behind the visible
strip rather than moving down the screen. Verify restoration after exit.
