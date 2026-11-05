import AppKit
import SwiftUI

private final class WindowSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class WindowSwitcherController: NSObject, NSWindowDelegate {
    static let shared = WindowSwitcherController()
    private enum Presentation { case standard, commandTab, expose }
    private var panel: NSPanel?
    private var exposePanels: [NSPanel] = []
    private var exposeScene: ExposeScene?
    private var exposePreparation: Task<Void, Never>?
    private var displayObserver: NSObjectProtocol?
    private let model = WindowSwitcherModel()
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var exposeClick = ExposeLayout.ClickSelection()
    private var flagsMonitor: Any?
    /// ⇧ pressed alone (no other key since) reveals the Rooms strip on release.
    private var shiftTapArmed = false
    private var shiftTapAt: TimeInterval = 0
    /// Debounces the two flagsChanged events a Caps Lock press can emit.
    private var lastCapsToggle: TimeInterval = 0
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var spaceObserver: NSObjectProtocol?
    private var appActivationObserver: NSObjectProtocol?
    private var activationTask: Task<Void, Never>?
    private var committingActivation = false
    private var interactionID = UUID()
    private var presentation = Presentation.standard
    private var commandTabOffset = 0
    private var commandTabApplied = false
    private var commitWhenReady = false

    var isVisible: Bool { panel?.isVisible == true || exposeScene != nil }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func toggleExpose() {
        if isVisible, presentation == .expose { endExpose(); return }
        showExpose()
    }

    func showExpose() {
        if isVisible { hide() }
        present(mode: .expose)
    }

    /// Settings can request Screen Recording without opening the picker first.
    func requestPreviews() { model.requestPreviews() }

    /// ⌘⇥ opens on the previous window; ⇧⌘⇥ on the least recently used one.
    /// Further presses accumulate while the inventory loads, then move live.
    func handleCommandTab(backwards: Bool) {
        // Cmd-Tab retains its normal window/Rooms view even from Exposé PK.
        if isVisible, presentation == .expose { hide() }
        if isVisible {
            // ⌘Tab always leaves Rooms mode: windows are one Tab press away.
            if model.showsRooms, !model.isCreatingRoom {
                model.exitRooms()
                return
            }
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
        } else if let target = model.selectedTarget {
            performActivation(target)
        } else {
            hide()
        }
    }

    /// Commit the selected target from any of the three visible sections.
    private func performActivation(_ target: WindowSwitcherTarget) {
        switch target {
        case .item(let id):
            if model.candidate(for: id) != nil {
                activate(id)
            } else {
                model.activateProcess(id)
            }
        case .room(let id):
            guard let room = model.roomStore.rooms.first(where: { $0.id == id }) else { hide(); return }
            model.activateRoom(room)
            hide()
        case .createRoom:
            model.beginRoomCreation()
        }
    }

    func show(message: String = "") {
        present(message: message, mode: .standard)
    }

    private func present(message: String = "", mode: Presentation, backwards: Bool = false) {
        if mode == .expose { presentExpose(); return }
        guard !isVisible else { return }
        // New picker session: drop any focus request left over from Exposé or
        // from a previous Cmd-Tab so clicks and Return always work.
        activationTask?.cancel()
        activationTask = nil
        committingActivation = false
        interactionID = UUID()
        presentation = mode
        commandTabOffset = mode == .commandTab && backwards ? -1 : 0
        commandTabApplied = false
        commitWhenReady = false
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        model.isExposePresentation = false
        let size = NSSize(width: min(1160, visible.width - 32), height: min(860, visible.height - 32))
        model.columns = size.width >= 1000 ? 4 : (size.width >= 740 ? 3 : (size.width >= 500 ? 2 : 1))
        model.cardHeight = WindowSwitcherState.cardHeight(forWidth: size.width, columns: model.columns)
        model.updateAuxiliaryColumns(forContentWidth: size.width - 36)
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

    /// Separate presentation path. Exposé never enters the switcher's sized,
    /// rounded/material panel. Each physical display gets a borderless surface.
    private func presentExpose() {
        guard !isVisible else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main,
              let scene = ExposeScene(screens: NSScreen.screens, active: screen) else { return }
        interactionID = UUID()
        presentation = .expose
        commandTabOffset = 0
        commandTabApplied = false
        commitWhenReady = false
        SpaceManagementService.shared.userChangedWindowSelection()
        activationTask?.cancel()
        activationTask = nil
        exposeScene = scene
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.hide() }
        model.isExposePresentation = true
        model.exposeCaptureSize = Self.exposeCaptureSize(for: scene.mode, scene: scene)
        scene.onModeChange = { [weak self, weak scene] mode in
            guard let self, let scene else { return }
            self.model.exposeCaptureSize = Self.exposeCaptureSize(for: mode, scene: scene)
            self.model.resetExposePreviews()
        }
        model.onReady = { [weak self] in self?.modelDidBecomeReady() }
        model.prepare()
    }

    private func prepareExposeScene(_ scene: ExposeScene) {
        exposePreparation?.cancel()
        scene.update(groups: model.exposeGroups, hasNotice: !model.accessibilityGranted || !model.previewsGranted || !model.message.isEmpty)
        let interaction = interactionID
        exposePreparation = Task { @MainActor [weak self, weak scene] in
            guard let self, let scene else { return }
            await scene.loadWallpapers()
            await self.model.warmExposePreviews()
            guard !Task.isCancelled, self.interactionID == interaction,
                  self.exposeScene === scene else { return }
            scene.update(groups: self.model.exposeGroups, hasNotice: !self.model.accessibilityGranted || !self.model.previewsGranted || !self.model.message.isEmpty)
            if self.exposePanels.isEmpty {
                scene.reveal(self.model.selectedID)
                self.showExposePanels(scene)
            }
            self.exposePreparation = nil
        }
    }

    private func showExposePanels(_ scene: ExposeScene) {
        for screen in scene.screens {
            let primary = screen.id == scene.activeID
            let overlay: NSPanel = primary
                ? WindowSwitcherPanel(contentRect: screen.appKitFrame,
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                : NSPanel(contentRect: screen.appKitFrame,
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            overlay.setFrame(screen.appKitFrame, display: false)
            overlay.isOpaque = false
            overlay.backgroundColor = .clear
            overlay.hasShadow = false
            overlay.isMovable = false
            overlay.hidesOnDeactivate = false
            overlay.isReleasedWhenClosed = false
            overlay.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
            overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            overlay.sharingType = .none
            let host = NSHostingView(rootView: ExposeView(model: model, scene: scene, screen: screen,
                onActivate: { [weak self] id in self?.activate(id) },
                onClose: { [weak self] in self?.endExpose() }))
            host.sizingOptions = []
            host.frame = NSRect(origin: .zero, size: screen.appKitFrame.size)
            host.autoresizingMask = [.width, .height]
            overlay.contentView = host
            if primary { overlay.delegate = self; panel = overlay }
            exposePanels.append(overlay)
        }
        installMonitors()
        // Without activating the app, macOS swallows the very first physical
        // click to activate us: the user had to click twice to pick a window.
        NSApp.activate(ignoringOtherApps: true)
        for overlay in exposePanels { overlay.orderFrontRegardless(); overlay.contentView?.layoutSubtreeIfNeeded() }
        panel?.makeKeyAndOrderFront(nil)
        let interaction = interactionID
        // Let the source rectangles commit once before animating their targets.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self, weak scene] in
            guard let self, let scene, self.interactionID == interaction,
                  self.exposeScene === scene, !scene.dismissing else { return }
            withAnimation(.easeInOut(duration: scene.entryDuration)) { scene.expanded = true }
        }
    }

    private func endExpose(activating id: WindowSwitcherID? = nil) {
        guard presentation == .expose, let scene = exposeScene else { hide(); return }
        guard !scene.dismissing else { return }
        guard panel?.isVisible == true else { hide(); return }
        // Capture the AX candidate now, never re-resolve the hover/selection
        // after the exit animation. A clicked Chrome window stays that window.
        let choice = id.flatMap { model.candidate(for: $0) }
        if let id, choice == nil {
            forceActivateApp(pid: id.pid)
            return
        }
        scene.dismissing = true
        let interaction = interactionID
        withAnimation(.easeInOut(duration: scene.exitDuration)) { scene.expanded = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + scene.exitDuration) { [weak self] in
            guard let self, self.interactionID == interaction else { return }
            self.hide() // Relinquish the fullscreen key panel BEFORE AX focus.
            if let choice { self.activateAfterExpose(choice) }
        }
    }

    /// Capture resolution matches what each mode actually shows on screen.
    private static func exposeCaptureSize(for mode: ExposeLayout.Mode, scene: ExposeScene) -> CGSize {
        let area = scene.availableArea
        guard mode == .strip else { return CGSize(width: 520, height: 400) }
        return CGSize(width: min(1280, area.width * 0.85), height: area.height)
    }

    /// The overlay and its key-focus enforcement are gone before focusing the
    /// captured window. Keep identity/launch-date validation in the inventory.
    private func activateAfterExpose(_ choice: WindowSwitcherInventory.Candidate) {
        SpaceManagementService.shared.userChangedWindowSelection()
        let ticket = SpaceManagementService.shared.windowSelectionTicket()
        let interaction = interactionID
        activationTask = Task { @MainActor [weak self] in
            let succeeded = await Task.detached(priority: .userInitiated) {
                WindowSwitcherInventory.activate(choice, selectionTicket: ticket)
            }.value
            guard let self else { return }
            // Clear FIRST: the picker may already have been reopened (new
            // interaction), and an early return must never poison the lock.
            self.activationTask = nil
            guard self.interactionID == interaction else { return }
            if !succeeded {
                // Never re-open a blocking overlay: bring the app forward.
                self.forceActivateApp(pid: choice.item.id.pid)
            }
        }
    }

    /// Explicit thumbnail hit regions, independent of transparent SwiftUI HUD
    /// layers. A release on another window/background cancels a drag/press.
    private func consumeExposeMouse(_ event: NSEvent) -> Bool {
        guard presentation == .expose, let scene = exposeScene,
              let index = exposePanels.firstIndex(where: { $0 === event.window }),
              scene.screens.indices.contains(index), !model.isBusy else { return false }
        let screen = scene.screens[index]
        let point = ExposeLayout.quartzPoint(fromLocal: event.locationInWindow, on: screen.frame)
        if event.type == .leftMouseDown { return exposeClick.press(scene.hitTest(point)) }
        if event.type == .leftMouseUp, exposeClick.hasPress {
            if let id = exposeClick.release(over: scene.hitTest(point)) {
                model.selectItem(id)
                activate(id)
            }
            return true
        }
        return false
    }

    func hide() {
        exposePreparation?.cancel()
        exposePreparation = nil
        exposeScene = nil
        // A focus request can outlive its picker session (Exposé closes, a new
        // Cmd-Tab opens). Never leave the controller locked behind a stale
        // task: every later click would silently do nothing.
        let hadFocusRequest = activationTask != nil
        activationTask?.cancel()
        activationTask = nil
        if hadFocusRequest {
            // Invalidate an in-flight focus request before dismissing.
            SpaceManagementService.shared.userChangedWindowSelection()
        }
        interactionID = UUID()
        committingActivation = false
        presentation = .standard
        commandTabOffset = 0
        commandTabApplied = false
        commitWhenReady = false
        removeMonitors()
        for overlay in exposePanels where overlay !== panel {
            overlay.orderOut(nil)
            overlay.contentView = nil
        }
        exposePanels.removeAll()
        let oldPanel = panel
        panel = nil
        oldPanel?.delegate = nil
        oldPanel?.orderOut(nil)
        oldPanel?.contentView = nil
        model.stop()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard isVisible, let panel, !committingActivation else { return }
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
        if presentation == .expose, let scene = exposeScene {
            prepareExposeScene(scene)
            return
        }
        if presentation == .commandTab, !commandTabApplied {
            commandTabApplied = true
            model.applyCommandTabOffset(commandTabOffset)
        }
        if commitWhenReady {
            commitWhenReady = false
            activateSelectionWhenReady()
        }
    }

    /// A Cmd-Tab pick must NEVER leave the panel on screen. If AX cannot
    /// resolve the exact window, activate its application and get out of the
    /// way; the user can still reach the target window.
    private func forceActivateApp(pid: Int32) {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
            hide()
            return
        }
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func activate(_ id: WindowSwitcherID) {
        if presentation == .expose, exposeScene?.expanded == true {
            endExpose(activating: id)
            return
        }
        if activationTask != nil {
            // An orphan request must not swallow this click/Return.
            activationTask?.cancel()
            activationTask = nil
            committingActivation = false
        }
        guard !model.isBusy, let candidate = model.candidate(for: id) else {
            forceActivateApp(pid: id.pid)
            return
        }
        SpaceManagementService.shared.userChangedWindowSelection()
        let ticket = SpaceManagementService.shared.windowSelectionTicket()
        let interaction = interactionID
        committingActivation = true
        activationTask = Task { @MainActor [weak self] in
            let succeeded = await Task.detached(priority: .userInitiated) {
                WindowSwitcherInventory.activate(candidate, selectionTicket: ticket)
            }.value
            guard let self else { return }
            self.activationTask = nil
            guard self.interactionID == interaction else { return }
            self.committingActivation = false
            if succeeded {
                self.hide()
            } else {
                // No dead end: dismiss and bring the owning app forward.
                self.forceActivateApp(pid: candidate.item.id.pid)
            }
        }
    }

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            return self.handleKey(event)
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            self.handleFlagsChanged(event)
            return event
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.hide()
        }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let scene = self.exposeScene, scene.mode == .strip,
                  self.exposePanels.contains(where: { $0 === event.window }) else { return event }
            let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
                ? event.scrollingDeltaX : event.scrollingDeltaY
            scene.scroll(by: -delta * (event.hasPreciseScrollingDeltas ? 1 : 30))
            return nil
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self else { return event }
            if self.consumeExposeMouse(event) { return nil }
            if event.type != .leftMouseUp, event.window !== self.panel,
               !self.exposePanels.contains(where: { $0 === event.window }) { self.hide() }
            return event
        }
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.hide() }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.hide() }
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, self.isVisible else { return }
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.processIdentifier != ProcessInfo.processInfo.processIdentifier,
               !self.committingActivation {
                self.hide()
            }
        }
    }

    private func removeMonitors() {
        for monitor in [keyMonitor, scrollMonitor, flagsMonitor, outsideClickMonitor, localClickMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil
        scrollMonitor = nil
        exposeClick = ExposeLayout.ClickSelection()
        flagsMonitor = nil
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
        displayObserver = nil
        shiftTapArmed = false
        outsideClickMonitor = nil
        localClickMonitor = nil
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        if let appActivationObserver { NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver) }
        appActivationObserver = nil
    }

    /// ⌘⇪ (Caps Lock) or a ⇧ tap while the picker is open switches the whole
    /// panel between Windows and Rooms. Holding ⇧ with ⇥ (⌘⇧Tab) cycles
    /// backwards as before: any keyDown cancels the ⇧ tap.
    private func handleFlagsChanged(_ event: NSEvent) {
        guard presentation != .expose else { return }
        if event.keyCode == 57 { // Caps Lock: one flagsChanged per press.
            guard !model.isCreatingRoom else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastCapsToggle > 0.3 else { return }
            lastCapsToggle = now
            model.enterOrAdvanceRooms()
            return
        }
        guard event.keyCode == 56 || event.keyCode == 60 else { return }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !modifiers.contains(.control), !modifiers.contains(.option) else {
            shiftTapArmed = false
            return
        }
        if modifiers.contains(.shift) {
            guard !model.isCreatingRoom else { return }
            shiftTapArmed = true
            shiftTapAt = ProcessInfo.processInfo.systemUptime
            return
        }
        guard shiftTapArmed else { return }
        shiftTapArmed = false
        guard ProcessInfo.processInfo.systemUptime - shiftTapAt < 0.45 else { return }
        model.enterOrAdvanceRooms()
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        if presentation == .expose { return handleExposeKey(event) }
        // Any real key cancels the pending ⇧-tap (⌘⇧Tab must not toggle Rooms).
        shiftTapArmed = false
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let key = event.charactersIgnoringModifiers?.lowercased()
        if model.forceQuitConfirmation != nil {
            if modifiers.isEmpty {
                switch event.keyCode {
                case 53: model.cancelForceQuit(); return nil
                case 36, 76:
                    if !event.isARepeat { model.confirmForceQuit() }
                    return nil
                case 48: return event
                default: return nil
                }
            }
            return nil
        }

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
            model.selectedTarget != nil || model.isLoading {
            if !event.isARepeat { activateSelectionWhenReady() }
            return nil
        }
        if modifiers == .command, handleTextShortcut(event, modifiers: modifiers) { return nil }
        if modifiers.isEmpty, model.navigationTargets.isEmpty, !model.query.isEmpty {
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
                if !event.isARepeat, let id = model.selectedID, model.candidate(for: id) != nil {
                    model.closeWindow(id)
                }
                return nil
            case "q":
                if !event.isARepeat, let id = model.selectedID {
                    if model.candidate(for: id) != nil {
                        model.quitApp(id)
                    } else {
                        model.quitProcess(id)
                    }
                }
                return nil
            default: break
            }
            if event.charactersIgnoringModifiers?.lowercased() == "r" {
                model.prepare(resetSearch: false)
                return nil
            }
            if let rank = Self.digitRanks[event.keyCode],
               !(presentation == .commandTab && !model.query.isEmpty) {
                if model.showsRooms {
                    let rooms = model.visibleRooms
                    if rooms.indices.contains(rank) {
                        if !event.isARepeat {
                            model.activateRoom(rooms[rank])
                            hide()
                        }
                    }
                } else if model.filteredItems.indices.contains(rank) {
                    activate(model.filteredItems[rank].id)
                }
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
            if let target = model.selectedTarget { performActivation(target) }
        case 48:
            if model.showsRooms, !model.isCreatingRoom {
                // Plain Tab exits Rooms mode, mirroring ⌘Tab.
                model.exitRooms()
            } else {
                model.moveSelection(modifiers.contains(.shift) ? -1 : 1)
            }
        case 123, 124:
            // Preserve caret navigation in a nonempty search query.
            guard model.query.isEmpty, modifiers.isEmpty else { return event }
            model.moveSelection(event.keyCode == 123 ? -1 : 1)
        case 125: model.moveSelectionVertically(1)
        case 126: model.moveSelectionVertically(-1)
        default: return event
        }
        return nil
    }

    private func handleExposeKey(_ event: NSEvent) -> NSEvent? {
        guard exposeScene?.dismissing != true else { return nil }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if (panel?.firstResponder as? NSTextView)?.hasMarkedText() == true { return event }
        if handleTextShortcut(event, modifiers: modifiers) { return nil }
        if WindowSwitcherState.confirmsWindowSelection(keyCode: event.keyCode,
                control: modifiers.contains(.control), option: modifiers.contains(.option)) {
            if !event.isARepeat { activateSelectionWhenReady() }
            return nil
        }
        if modifiers == .command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "r": model.prepare(resetSearch: false); return nil
            case "w":
                if !event.isARepeat, let id = model.selectedID { model.closeWindow(id) }
                return nil
            case "q":
                if !event.isARepeat, let id = model.selectedID { model.quitApp(id) }
                return nil
            default: return event
            }
        }
        guard modifiers.isEmpty || modifiers == .shift else { return event }
        switch event.keyCode {
        case 53: endExpose()
        case 48: model.moveSelection(modifiers == .shift ? -1 : 1)
        case 123, 124:
            guard model.query.isEmpty, modifiers.isEmpty else { return event }
            model.moveSelection(event.keyCode == 123 ? -1 : 1)
        case 125, 126: model.moveExposeGroup(event.keyCode == 126 ? -1 : 1)
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
