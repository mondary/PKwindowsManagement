# Desktop order and horizontal Canvas

Approved scope (2026-10-09):

1. Reorder the active native desktop left/right by dragging its Mission Control
   thumbnail. Preserve desktop identity, contents and focus; verify actual order.
2. An opt-in strip of real windows on the current desktop: next/previous focus,
   comfortable widths, adoption of new windows and restoration on exit.
3. Modifier + horizontal trackpad/wheel scrolling and independent display strips.

Native Swift/AppKit and Accessibility. Reuse the existing shortcut/settings
pipeline. Dev-channel delivery and real macOS validation at each milestone.

References: PaperWM.spoon (MIT), Paneru (MIT), ScrollWM (MIT); interaction
inspiration: OnePlus Open Canvas. Implement locally rather than run a second
window manager. Account for macOS off-screen constraints and monitor seams.

Manual validation: reorder A/B/C in both directions with windows on each; verify
Space IDs/order and unchanged membership. Canvas: multiple windows of the same
app, focus via keyboard/click, new/closed windows, modal/fullscreen exclusions,
repeated scrolling, monitor unplugging, Space changes, exact restoration.
