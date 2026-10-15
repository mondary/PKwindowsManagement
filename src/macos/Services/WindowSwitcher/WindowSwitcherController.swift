import AppKit
import SwiftUI

private final class WindowSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class WindowSwitcherController: NSObject, NSWindowDelegate {
    static let shared = WindowSwitcherController()
    private var panel: NSPanel?
    private let model = WindowSwitcherModel()
    private var keyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var spaceObserver: NSObjectProtocol?
    private var activationTask: Task<Void, Never>?
    private var interactionID = UUID()

    var isVisible: Bool { panel?.isVisible == true }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show(message: String = "") {
        guard !isVisible else { return }
        interactionID = UUID()
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = NSSize(width: min(880, visible.width - 32), height: min(640, visible.height - 32))
        model.columns = size.width >= 740 ? 3 : (size.width >= 500 ? 2 : 1)
        model.message = message
        model.prepare()
        let panel = WindowSwitcherPanel(
            contentRect: NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                                width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        let hosting = NSHostingView(rootView: WindowSwitcherView(model: model, onActivate: { [weak self] id in
            self?.activate(id)
        }, onClose: { [weak self] in self?.hide() }))
        // A wrapping permission banner must not enlarge the borderless panel
        // to SwiftUI's unconstrained intrinsic height before its first layout.
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.setContentSize(size)
        self.panel = panel
        installMonitors()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        interactionID = UUID()
        removeMonitors()
        let oldPanel = panel
        panel = nil
        oldPanel?.delegate = nil
        oldPanel?.orderOut(nil)
        oldPanel?.contentView = nil
        model.stop()
    }

    func windowDidResignKey(_ notification: Notification) { hide() }

    private func activate(_ id: WindowSwitcherID) {
        guard activationTask == nil, model.closingID == nil, let candidate = model.candidate(for: id) else { return }
        SpaceManagementService.shared.userChangedWindowSelection()
        let ticket = SpaceManagementService.shared.windowSelectionTicket()
        hide()
        let interaction = interactionID
        activationTask = Task { @MainActor [weak self] in
            let succeeded = await Task.detached(priority: .userInitiated) {
                WindowSwitcherInventory.activate(candidate, selectionTicket: ticket)
            }.value
            guard let self else { return }
            self.activationTask = nil
            if !succeeded, !self.isVisible, self.interactionID == interaction,
               SpaceManagementService.shared.windowSelectionTicket() == ticket {
                self.show(message: localizedString("This window is no longer available or could not be activated. Try refreshing the list."))
            }
        }
    }

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            return self.handleKey(event)
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.hide()
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            if let self, event.window !== self.panel { self.hide() }
            return event
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.hide() }
    }

    private func removeMonitors() {
        for monitor in [keyMonitor, outsideClickMonitor, localClickMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil
        outsideClickMonitor = nil
        localClickMonitor = nil
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers == .command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "w":
                if !event.isARepeat, let id = model.selectedID { model.closeWindow(id) }
                return nil
            case "q":
                model.message = localizedString("Use ⌘W to close only the selected window. ⌘Q is disabled in this picker.")
                return nil
            default: break
            }
            if event.charactersIgnoringModifiers?.lowercased() == "r" {
                model.prepare(resetSearch: false)
                return nil
            }
            if let rank = Self.digitRanks[event.keyCode], model.filteredItems.indices.contains(rank) {
                activate(model.filteredItems[rank].id)
                return nil
            }
            return event
        }
        // Let input methods finish composition before using arrows/Return/Esc.
        if let editor = panel?.firstResponder as? NSTextView, editor.hasMarkedText() { return event }
        guard modifiers.isEmpty || modifiers == .shift else { return event }
        switch event.keyCode {
        case 53: hide()
        case 36, 76:
            if let id = model.selectedID { activate(id) }
        case 48: model.moveSelection(modifiers.contains(.shift) ? -1 : 1)
        case 123, 124:
            // Preserve caret navigation in a nonempty search query.
            guard model.query.isEmpty, modifiers.isEmpty else { return event }
            model.moveSelection(event.keyCode == 123 ? -1 : 1)
        case 125: model.moveSelection(model.columns, wrapping: false)
        case 126: model.moveSelection(-model.columns, wrapping: false)
        default: return event
        }
        return nil
    }

    private static let digitRanks: [UInt16: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8,
        83: 0, 84: 1, 85: 2, 86: 3, 87: 4, 88: 5, 89: 6, 91: 7, 92: 8
    ]
}
