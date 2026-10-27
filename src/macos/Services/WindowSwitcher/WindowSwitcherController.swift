import AppKit
import SwiftUI

private final class WindowSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class WindowSwitcherController: NSObject, NSWindowDelegate {
    static let shared = WindowSwitcherController()
    private enum Presentation { case standard, commandTab }
    private var panel: NSPanel?
    private let model = WindowSwitcherModel()
    private var keyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var spaceObserver: NSObjectProtocol?
    private var appActivationObserver: NSObjectProtocol?
    private var activationTask: Task<Void, Never>?
    private var interactionID = UUID()
    private var presentation = Presentation.standard
    private var commandTabOffset = 0
    private var commandTabApplied = false
    private var commitWhenReady = false

    var isVisible: Bool { panel?.isVisible == true }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    /// Settings can request Screen Recording without opening the picker first.
    func requestPreviews() { model.requestPreviews() }

    /// ⌘⇥ opens on the previous window; ⇧⌘⇥ on the least recently used one.
    /// Further presses accumulate while the inventory loads, then move live.
    func handleCommandTab(backwards: Bool) {
        if isVisible {
            // A picker opened from the menu/hotkey becomes a hold-Command
            // session too, otherwise its release would be ignored.
            if presentation != .commandTab {
                presentation = .commandTab
                commandTabApplied = !model.isLoading
                commandTabOffset = 0
            }
            if presentation == .commandTab, !commandTabApplied {
                commandTabOffset += backwards ? -1 : 1
            } else {
                model.moveSelection(backwards ? -1 : 1)
            }
            return
        }
        present(mode: .commandTab, backwards: backwards)
    }

    /// Releasing ⌘ commits the current selection, like the system switcher.
    /// Sticky mode only defers that commit while a filter is being refined:
    /// without a query there is nothing left to type, so a plain ⌘⇥ release
    /// must still switch windows instead of leaving the picker on screen.
    func commitCommandTab() {
        guard isVisible, presentation == .commandTab else { return }
        if WindowSwitcherState.defersCommandTabCommit(
            sticky: AppRuntime.shared.settings?.windowSwitcherStickyCommandTab == true,
            query: model.query) { return }
        activateSelectionWhenReady()
    }

    private func activateSelectionWhenReady() {
        // Refresh may still expose the previous selection. Wait for the new
        // inventory before resolving the target rather than silently losing
        // an early Return/release against an empty candidate dictionary.
        if model.isLoading {
            commitWhenReady = true
        } else if let id = model.selectedID {
            activate(id)
        } else {
            hide()
        }
    }

    func show(message: String = "") {
        present(message: message, mode: .standard)
    }

    private func present(message: String = "", mode: Presentation, backwards: Bool = false) {
        guard !isVisible else { return }
        interactionID = UUID()
        presentation = mode
        commandTabOffset = mode == .commandTab && backwards ? -1 : 0
        commandTabApplied = false
        commitWhenReady = false
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = NSSize(width: min(1120, visible.width - 32), height: min(800, visible.height - 32))
        model.columns = size.width >= 1000 ? 4 : (size.width >= 740 ? 3 : (size.width >= 500 ? 2 : 1))
        model.cardHeight = WindowSwitcherState.cardHeight(forWidth: size.width, columns: model.columns)
        model.message = message
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
        let hosting = NSHostingView(rootView: WindowSwitcherView(model: model, roomStore: model.roomStore, onActivate: { [weak self] id in
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
        model.onReady = { [weak self] in self?.modelDidBecomeReady() }
        model.prepare()
    }

    func hide() {
        interactionID = UUID()
        presentation = .standard
        commandTabOffset = 0
        commandTabApplied = false
        commitWhenReady = false
        removeMonitors()
        let oldPanel = panel
        panel = nil
        oldPanel?.delegate = nil
        oldPanel?.orderOut(nil)
        oldPanel?.contentView = nil
        model.stop()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard isVisible, let panel else { return }
        // A picker control can hand key status to the Settings window behind
        // the panel. Keep the picker interactive by taking key status back;
        // switching to another app is handled by the activation observer.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible, self.panel === panel else { return }
            self.panel?.makeKey()
        }
    }

    private func modelDidBecomeReady() {
        guard isVisible else { return }
        if presentation == .commandTab, !commandTabApplied {
            commandTabApplied = true
            model.applyCommandTabOffset(commandTabOffset)
        }
        if commitWhenReady {
            commitWhenReady = false
            activateSelectionWhenReady()
        }
    }

    private func activate(_ id: WindowSwitcherID) {
        guard activationTask == nil, !model.isBusy, let candidate = model.candidate(for: id) else { return }
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
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, self.isVisible else { return }
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                self.hide()
            }
        }
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
        if let appActivationObserver { NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver) }
        appActivationObserver = nil
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let key = event.charactersIgnoringModifiers?.lowercased()

        // ⌘K room actions overlay has priority over everything else.
        if model.roomActionTargetID != nil || model.renamingRoomID != nil {
            if modifiers == .command {
                if handleTextShortcut(event, modifiers: modifiers) { return nil }
                if key == "k" { model.closeRoomActions() }
                return nil
            }
            if model.renamingRoomID != nil {
                if modifiers.isEmpty, event.keyCode == 53 {
                    model.renamingRoomID = nil
                    return nil
                }
                if modifiers.isEmpty, event.keyCode == 36 || event.keyCode == 76 {
                    if !event.isARepeat { model.commitRename() }
                    return nil
                }
                return event
            }
            if modifiers.isEmpty {
                switch event.keyCode {
                case 53: model.closeRoomActions(); return nil
                case 125: model.moveRoomActionSelection(1); return nil
                case 126: model.moveRoomActionSelection(-1); return nil
                case 36, 76:
                    if !event.isARepeat { model.performRoomAction() }
                    return nil
                default: break
                }
            }
            // ⌥⇥ room cycling waits until the menu is closed.
            if modifiers == [.option] || modifiers == [.option, .shift], event.keyCode == 48 { return nil }
            return event
        }

        if !model.isCreatingRoom, modifiers == .command, key == "n" {
            model.beginRoomCreation()
            return nil
        }
        if !model.isCreatingRoom, modifiers == .command, key == "k",
           !model.roomStore.rooms.isEmpty {
            model.openRoomActions()
            return nil
        }
        // ⌥⇥ next room, ⌥⇧⇥ previous room — activates immediately.
        if !model.isCreatingRoom,
           modifiers == [.option] || modifiers == [.option, .shift], event.keyCode == 48 {
            if let room = model.roomForCycle(forward: modifiers == [.option]) {
                model.activateRoom(room)
                hide()
            }
            return nil
        }
        if model.isCreatingRoom {
            if modifiers.isEmpty, event.keyCode == 53 {
                model.cancelRoomCreation()
                return nil
            }
            if modifiers.isEmpty, event.keyCode == 36 || event.keyCode == 76 {
                if !event.isARepeat { model.createRoom() }
                return nil
            }
            if modifiers == [.option], event.keyCode == 49, let id = model.selectedID {
                model.toggleRoomPick(id)
                return nil
            }
            // Keep window activation and close/quit commands out of room mode.
            if modifiers == .command {
                if key == "w" || key == "q" || Self.digitRanks[event.keyCode] != nil { return nil }
            }
        }
        // Return is an explicit confirmation even while Command is held.
        // Handle it before the Command text/shortcut branch, but leave room
        // forms, menus and IME composition in control of their own Return.
        if !model.isCreatingRoom,
           WindowSwitcherState.confirmsWindowSelection(
            keyCode: event.keyCode, control: modifiers.contains(.control), option: modifiers.contains(.option)),
           (panel?.firstResponder as? NSTextView)?.hasMarkedText() != true,
           model.selectedID != nil || model.isLoading {
            if !event.isARepeat { activateSelectionWhenReady() }
            return nil
        }
        if modifiers == .command, handleTextShortcut(event, modifiers: modifiers) { return nil }
        if modifiers.isEmpty, model.filteredItems.isEmpty, !model.query.isEmpty {
            switch event.keyCode {
            case 125: model.moveFallbackSelection(1); return nil
            case 126: model.moveFallbackSelection(-1); return nil
            case 36, 76:
                if !event.isARepeat, model.performSelectedFallback() { hide() }
                return nil
            default: break
            }
        }
        if modifiers == .command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "w":
                if !event.isARepeat, let id = model.selectedID { model.closeWindow(id) }
                return nil
            case "q":
                if !event.isARepeat, let id = model.selectedID { model.quitApp(id) }
                return nil
            default: break
            }
            if event.charactersIgnoringModifiers?.lowercased() == "r" {
                model.prepare(resetSearch: false)
                return nil
            }
            if let rank = Self.digitRanks[event.keyCode], model.filteredItems.indices.contains(rank),
               !(presentation == .commandTab && !model.query.isEmpty) {
                activate(model.filteredItems[rank].id)
                return nil
            }
            if typesCommandTabText(event) { return nil }
            return event
        }
        if presentation == .commandTab, modifiers == [.command, .shift] {
            if typesCommandTabText(event) { return nil }
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

    /// The picker is a borderless panel without a menu bar: standard text
    /// shortcuts (⌘A/⌘C/⌘X/⌘V/⌘Z) must be forwarded to the field editor.
    private func handleTextShortcut(_ event: NSEvent, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard modifiers == .command,
              let key = event.charactersIgnoringModifiers?.lowercased(),
              let editor = panel?.firstResponder as? NSTextView else { return false }
        switch key {
        case "a": editor.selectAll(nil); return true
        case "c": editor.copy(nil); return true
        case "x": editor.cut(nil); return true
        case "v": editor.paste(nil); return true
        case "z": editor.undoManager?.undo(); return true
        default: return false
        }
    }

    private static let digitRanks: [UInt16: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8,
        83: 0, 84: 1, 85: 2, 86: 3, 87: 4, 88: 5, 89: 6, 91: 7, 92: 8
    ]

    /// ⌘ is still held while typing in the hold-mode picker. Treat printable
    /// keys as search input instead of letting AppKit resolve them as commands.
    private func typesCommandTabText(_ event: NSEvent) -> Bool {
        guard presentation == .commandTab else { return false }
        switch event.keyCode {
        case 51, 117:
            if !model.query.isEmpty { model.query.removeLast() }
            return true
        default:
            break
        }
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return false }
        let printable = String(characters.filter { character in
            character.unicodeScalars.allSatisfy { scalar in
                !CharacterSet.controlCharacters.contains(scalar)
                    && !(0xF700...0xF8FF).contains(scalar.value)
            }
        })
        guard !printable.isEmpty else { return false }
        model.query += printable
        return true
    }
}
