import AppKit
import SwiftUI

private final class RoomsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Compact floating panel hosting the Rooms switcher, opened from the menu bar
/// item or the global ⌃⌥R hotkey. Keyboard: Escape closes, Return walks into
/// the selected room, Tab / ⇧Tab cycles its layout, ⌘⌫ deletes it, ↑↓ move the
/// selection.
final class RoomsOverlayController {
    static let shared = RoomsOverlayController()

    private var panel: NSPanel?
    private let model = RoomsSwitcherModel()
    private var keyMonitor: Any?

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard panel?.isVisible != true else { return }
        model.prepare()

        let size = NSSize(width: 560, height: 540)
        let origin = centeredOrigin(size: size)
        let panel = RoomsPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.isMovable = false

        let hosting = NSHostingController(
            rootView: RoomsSwitcherView(model: model, onActivateRoom: { [weak self] in
                self?.hide()
            })
        )
        hosting.view.frame = NSRect(origin: .zero, size: size)
        hosting.view.autoresizingMask = [.width, .height]
        panel.contentView = hosting.view

        self.panel = panel
        installKeyMonitor()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        // Give the search field the keyboard, like a Spotlight panel.
        DispatchQueue.main.async {
            panel.makeFirstResponder(hosting.view)
        }
    }

    func hide() {
        panel?.orderOut(nil)
        removeKeyMonitor()
    }

    // MARK: Keyboard

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            return self.handleKey(event)
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    /// Returns nil when the event was consumed.
    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Escape: leave creation first, then close the panel.
        if event.keyCode == 53 {
            if model.isCreating {
                model.isCreating = false
            } else {
                hide()
            }
            return nil
        }

        if model.isCreating {
            if event.keyCode == 36, model.canCreateRoom {  // Return
                model.createRoom()
                return nil
            }
            return event
        }

        switch event.keyCode {
        case 48:  // Tab / ⇧Tab
            model.cycleLayout(forward: !modifiers.contains(.shift))
            return nil
        case 36, 76:  // Return / keypad Enter
            if model.activateSelected() { hide() }
            return nil
        case 51:  // Delete
            if modifiers.contains(.command) {
                model.deleteSelected()
                return nil
            }
            return event
        case 125:  // ↓
            model.moveSelection(1)
            return nil
        case 126:  // ↑
            model.moveSelection(-1)
            return nil
        default:
            return event
        }
    }

    // MARK: Placement

    private func centeredOrigin(size: NSSize) -> NSPoint {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        return NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
    }
}
