import AppKit
import Combine
import OSLog

/// Paneru-style scrolling grid of real AX windows (see docs/canvas-plan.md):
/// mixed one/two-row columns per display, a horizontally scrolling viewport,
/// off-screen columns parked as edge slivers, and an exact-restore journal.
/// Layout and external AX work are serial and off the main thread. AX calls
/// targeting our own windows run on main because they enter AppKit directly.
final class HorizontalCanvasService: ObservableObject {
    static let shared = HorizontalCanvasService()
    static let stateDidChange = Notification.Name("PKCanvasStateDidChange")
    @Published private(set) var activeDisplayIDs: Set<CGDirectDisplayID> = []
    @Published private(set) var message = ""
    @Published private(set) var inventoryMessage = ""
    @Published private(set) var currentWorkspace: TilingWorkspaceSnapshot?
    /// Main-thread snapshots for the minimap bars; rebuilt by publish() on
    /// the worker after every layout, scroll or selection change.
    @Published private(set) var minimaps: [CGDirectDisplayID: CanvasMinimap.Model] = [:]

    private struct Display {
        let id: CGDirectDisplayID
        let uuid: String
        let bounds: CGRect
        let area: CGRect
    }

    private struct Context {
        let displays: [Display]
        let apps: [pid_t: Date]
        let hiddenPIDs: Set<pid_t>
        let frontmostPID: pid_t?
        let pointer: CGPoint

        static func capture() -> Context {
            precondition(Thread.isMainThread)
            let top = NSScreen.screens.first?.frame.maxY ?? 0
            let displays = NSScreen.screens.compactMap { screen -> Display? in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                      let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
                let visible = screen.visibleFrame
                return Display(
                    id: id,
                    uuid: CFUUIDCreateString(nil, uuid) as String,
                    bounds: CGDisplayBounds(id),
                    area: CGRect(x: visible.minX + 12, y: top - visible.maxY + 12,
                                 width: max(1, visible.width - 24), height: max(1, visible.height - 24))
                )
            }
            let apps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy != .prohibited
            }.reduce(into: [pid_t: Date]()) { result, app in
                if let date = app.launchDate { result[app.processIdentifier] = date }
            }
            let pointer = NSEvent.mouseLocation
            return Context(
                displays: displays,
                apps: apps,
                hiddenPIDs: Set(NSWorkspace.shared.runningApplications.filter(\.isHidden).map(\.processIdentifier)),
                frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                pointer: CGPoint(x: pointer.x, y: top - pointer.y)
            )
        }
    }

    private struct SavedWindow: Codable {
        let id: CGWindowID
        let pid: pid_t
        let launchedAt: Date
        let frame: CGRect
        let space: UInt64
    }

    private final class Entry {
        let saved: SavedWindow
        let window: AXUIElement
        var lastFrame: CGRect?
        var minimumWidth: CGFloat = 0
        init(saved: SavedWindow, window: AXUIElement) {
            self.saved = saved
            self.window = window
        }
    }

    private final class Strip {
        var display: Display
        let space: UInt64
        let defaultWidth: CGFloat
        /// Discovery order; arrangement stores the explicit column membership.
        var entries: [Entry] = []
        var arrangement = CanvasArrangement()
        var columns: [CanvasLayout.Column] = []
        var widths: [CGFloat] = []
        var selected: CGWindowID?
        var viewport: CGFloat = 0
        var layout: TilingLayoutKind = .canvas
        var lastNavigation: TimeInterval = 0
        var suspended = false
        init(display: Display, space: UInt64, defaultWidth: CGFloat, layout: TilingLayoutKind = .canvas) {
            self.display = display
            self.space = space
            self.defaultWidth = defaultWidth
            self.layout = layout
        }
    }

    private let queue = DispatchQueue(label: "pk.windows-management.canvas", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.mondary.PKwindowsManagement", category: "Canvas")
    private var strips: [CanvasWorkspace: Strip] = [:]
    /// Half-height choices survive deactivation: the arrangement is kept when
    /// the strip is released and restored when the same desktop reactivates.
    private var arrangements: [CanvasWorkspace: CanvasArrangement] = [:]
    private var knownWorkspaces: Set<CanvasWorkspace> = [] // main thread snapshot
    private var pendingScrolls: [CanvasWorkspace: CGFloat] = [:] // main thread only
    private var scrollFlushScheduled = false // main thread only
    private var saved: [CGWindowID: SavedWindow] = [:]
    private var recoveryLoaded = false
    private var timer: Timer?
    private var tickPending = false // main thread only
    private var shuttingDown = false // main thread only
    /// Room activation temporarily releases managed frames while RoomEngine
    /// performs its one-shot placement. The persistent Space profile remains
    /// enabled and is reapplied once the room handoff completes.
    private var roomHandoffs: [String: CanvasWorkspace] = [:] // worker queue only
    private var spaceObserver: NSObjectProtocol?
    private let restoreURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PKwindowsManagement/CanvasRestore.json")

    func start() {
        precondition(Thread.isMainThread)
        guard timer == nil else { return }
        // AX inventory reads are cross-process calls. A slower observer keeps
        // discovery responsive without repeatedly stalling active applications.
        timer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true) { [weak self] _ in self?.tick() }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick() }
        refreshCurrentWorkspace()
        tick()
    }

    /// Refreshes the profile shown in settings/menu for the pointer's current
    /// display and native Space. Selection is deliberately separate from the
    /// worker-owned strip dictionary.
    func refreshCurrentWorkspace() {
        precondition(Thread.isMainThread)
        let context = Context.capture()
        guard let display = context.displays.first(where: { $0.bounds.contains(context.pointer) })
                ?? context.displays.first,
              let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else {
            currentWorkspace = nil
            return
        }
        let key = TilingWorkspaceKey(displayUUID: display.uuid, spaceID: space)
        let profile = TilingWorkspaceProfiles.profile(for: key, in: TilingWorkspaceProfiles.load())
        let index = NSScreen.screens.firstIndex {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.id
        } ?? 0
        let snapshot = TilingWorkspaceSnapshot(key: key, displayID: display.id,
            displayName: String(format: localizedString("Screen %d"), index + 1), profile: profile)
        if currentWorkspace != snapshot { currentWorkspace = snapshot }
    }

    func toggleCurrentTilingMode() {
        let profile = currentProfileForPointer()
        setCurrentTilingMode(profile.mode == .tiling ? .free : .tiling)
    }

    func setCurrentTilingMode(_ mode: TilingMode) {
        updateCurrentProfile { $0.mode = mode }
    }

    func setCurrentLayout(_ layout: TilingLayoutKind) {
        updateCurrentProfile { $0.layout = layout }
    }

    /// One-shot snap commands leave continuous ownership on the current Space;
    /// otherwise the periodic tiler would immediately undo the user's manual
    /// placement after the legacy Canvas release path.
    func releaseForManualPlacement(completion: @escaping () -> Void) {
        precondition(Thread.isMainThread)
        setCurrentTilingMode(.free)
        release(completion: completion)
    }

    private func currentProfileForPointer() -> TilingWorkspaceProfile {
        precondition(Thread.isMainThread)
        let context = Context.capture()
        guard let display = context.displays.first(where: { $0.bounds.contains(context.pointer) })
                ?? context.displays.first,
              let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else {
            return TilingWorkspaceProfile()
        }
        let key = TilingWorkspaceKey(displayUUID: display.uuid, spaceID: space)
        return TilingWorkspaceProfiles.profile(for: key, in: TilingWorkspaceProfiles.load())
    }

    private func updateCurrentProfile(_ update: (inout TilingWorkspaceProfile) -> Void) {
        precondition(Thread.isMainThread)
        let context = Context.capture()
        guard let display = context.displays.first(where: { $0.bounds.contains(context.pointer) })
                ?? context.displays.first,
              let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else {
            message = localizedString("No active desktop is available for tiling.")
            return
        }
        let key = TilingWorkspaceKey(displayUUID: display.uuid, spaceID: space)
        var profile = TilingWorkspaceProfiles.profile(for: key, in: TilingWorkspaceProfiles.load())
        update(&profile)
        guard TilingWorkspaceProfiles.update(profile, for: key) else {
            message = localizedString("Tiling preferences could not be saved.")
            return
        }
        AppRuntime.shared.settings?.scheduleAutoBackup()
        refreshCurrentWorkspace()
        let workspace = CanvasWorkspace(displayID: display.id, spaceID: space)
        queue.async {
            if profile.mode == .tiling {
                guard AXIsProcessTrusted() else {
                    self.report("Tiling needs Accessibility permission.")
                    return
                }
                if let strip = self.strips[workspace], self.isCurrent(strip) {
                    strip.layout = profile.layout
                    strip.entries.forEach { $0.lastFrame = nil }
                    strip.viewport = 0
                    self.retile(strip)
                    if strip.layout == .canvas { self.fitViewport(strip) }
                    self.teleport(strip, context: context)
                } else {
                    self.activate(workspace: workspace, display: display, space: space,
                                  profile: profile, context: context)
                }
            } else if let strip = self.strips.removeValue(forKey: workspace) {
                self.arrangements[workspace] = strip.arrangement
                self.restore(strip.entries.map(\.saved), context: context)
                self.publish()
            } else {
                self.publish()
            }
        }
    }

    /// Establish ownership only after the profile is durable and the recovery
    /// journal can be written. The periodic inventory pass calls this again if
    /// no compatible windows exist yet, so future windows still join.
    private func activate(workspace: CanvasWorkspace, display: Display, space: UInt64,
                          profile: TilingWorkspaceProfile, context: Context) {
        guard profile.mode == .tiling, strips[workspace] == nil,
              !roomHandoffs.values.contains(workspace), isDesktopCurrent(space, display: display) else { return }
        guard loadRecovery(context) else { return }
        let entries = discover(context, on: display, space: space, diagnose: false, reconcile: true)
        guard !entries.isEmpty else { return }

        let previous = arrangements[workspace]
        let geometry = CanvasLayout.Geometry(area: display.area, rows: 2)
        let strip = Strip(
            display: display,
            space: space,
            defaultWidth: geometry.defaultColumnWidth(
                columns: CanvasLayout.preferredColumns(forAreaWidth: display.area.width)
            ),
            layout: profile.layout
        )
        strip.entries = entries
        if let previous { strip.arrangement = previous }
        let focused = CanvasWindowAccess.focusedID(pid: context.frontmostPID)
        strip.selected = entries.first(where: { $0.saved.id == focused })?.saved.id ?? entries.first?.saved.id
        for entry in entries { saved[entry.saved.id] = entry.saved }
        guard persist() else {
            for entry in entries { saved.removeValue(forKey: entry.saved.id) }
            return
        }
        strips[workspace] = strip
        retile(strip)
        if strip.layout == .canvas { fitViewport(strip) }
        teleport(strip, context: context)
        if strip.layout == .canvas { focusSelected(strip) }
    }

    private func isDesktopCurrent(_ space: UInt64, display: Display) -> Bool {
        SpaceManagementService.userDesktop(onDisplay: display.uuid) == space
    }

    func perform(_ action: CanvasAction) {
        precondition(Thread.isMainThread)
        guard !shuttingDown else { return }
        if action == .toggle {
            updateCurrentProfile {
                if $0.mode == .tiling && $0.layout == .canvas {
                    $0.mode = .free
                } else {
                    $0.layout = .canvas
                    $0.mode = .tiling
                }
            }
            return
        }
        if action == .restore {
            setCurrentTilingMode(.free)
            return
        }
        message = ""
        let context = Context.capture()
        queue.async {
            guard AXIsProcessTrusted() else { self.report("Canvas needs Accessibility permission."); return }
            if action == .inspect {
                guard let display = self.targetDisplay(context, focused: CanvasWindowAccess.focusedID(pid: context.frontmostPID)),
                      let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else { return }
                _ = self.discover(context, on: display, space: space, diagnose: true, reconcile: true)
                return
            }
            guard self.loadRecovery(context) else { return }
            let focused = CanvasWindowAccess.focusedID(pid: context.frontmostPID)
            let display = self.targetDisplay(context, focused: focused)
            guard let display else { self.report("No display available for Canvas."); return }
            guard let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else {
                self.report("Canvas requires a normal desktop."); return
            }
            let workspace = CanvasWorkspace(displayID: display.id, spaceID: space)
            if let strip = self.strips[workspace], self.isCurrent(strip) {
                guard strip.layout == .canvas, !strip.entries.isEmpty, !strip.widths.isEmpty else { return }
                if action == .fullHeight || action == .halfHeight {
                    // Read actual focus now, rather than waiting for the periodic
                    // observer: a click followed by a shortcut must affect that window.
                    guard let focused,
                          let entry = strip.entries.first(where: { $0.saved.id == focused }) else { return }
                    strip.selected = focused
                    if action == .halfHeight { strip.arrangement.setHalfHeight(entry.saved.id) }
                    else { strip.arrangement.setFullHeight(entry.saved.id) }
                    self.retile(strip)
                    self.fitViewport(strip)
                    self.teleport(strip, context: context)
                    self.focusSelected(strip)
                    return
                }
                let index = strip.entries.firstIndex(where: { $0.saved.id == strip.selected }) ?? 0
                if action == .moveColumnLeft || action == .moveColumnRight {
                    strip.arrangement.moveColumn(containing: strip.entries[index].saved.id,
                        by: action == .moveColumnLeft ? -1 : 1)
                    self.retile(strip)
                    self.fitViewport(strip)
                    self.teleport(strip, context: context)
                    self.focusSelected(strip)
                    return
                }
                guard let slot = CanvasLayout.slot(index: index, columns: strip.columns) else { return }
                let column = slot.column
                let row = slot.row
                let vertical = action == .above || action == .below
                let targetColumn = vertical ? column : min(max(0, column + (action == .next ? 1 : -1)), strip.widths.count - 1)
                let targetRow = vertical ? row + (action == .below ? 1 : -1) : row
                guard let targetIndex = CanvasLayout.index(column: targetColumn, row: targetRow,
                                                           columns: strip.columns) else { return }
                strip.selected = strip.entries[targetIndex].saved.id
                strip.lastNavigation = ProcessInfo.processInfo.systemUptime
                self.fitViewport(strip)
                self.teleport(strip, context: context)
                self.focusSelected(strip)
            }
        }
    }

    /// Minimap click: travel to a column on the display that owns the bar.
    /// Same guards and placement pass as keyboard navigation; the publish()
    /// inside teleport() refreshes the bar.
    func focusColumn(_ column: Int, on displayID: CGDirectDisplayID) {
        precondition(Thread.isMainThread)
        guard !shuttingDown else { return }
        message = ""
        let context = Context.capture()
        queue.async {
            guard AXIsProcessTrusted() else { self.report("Canvas needs Accessibility permission."); return }
            guard self.loadRecovery(context) else { return }
            guard let workspace = self.strips.keys.first(where: { $0.displayID == displayID }),
                  let strip = self.strips[workspace], self.isCurrent(strip),
                  strip.layout == .canvas,
                  !strip.entries.isEmpty, !strip.widths.isEmpty else { return }
            let clamped = min(max(0, column), strip.widths.count - 1)
            guard let index = CanvasLayout.index(column: clamped, row: 0, columns: strip.columns) else { return }
            strip.selected = strip.entries[index].saved.id
            strip.lastNavigation = ProcessInfo.processInfo.systemUptime
            self.fitViewport(strip)
            self.teleport(strip, context: context)
            self.focusSelected(strip)
        }
    }

    /// Continuous horizontal/Option scroll. Never read the worker-owned strips on
    /// the event-tap thread; knownWorkspaces is the main-thread snapshot.
    func scroll(rawDelta: CGFloat, location: CGPoint) -> Bool {
        precondition(Thread.isMainThread)
        guard !shuttingDown else { return false }
        guard let displayID = NSScreen.screens.compactMap({ screen -> CGDirectDisplayID? in
            screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        }).first(where: { CGDisplayBounds($0).contains(location) }),
              let workspace = knownWorkspaces.first(where: { $0.displayID == displayID }) else { return false }
        pendingScrolls[workspace, default: 0] -= rawDelta
        scheduleScrollFlush()
        return true
    }

    /// Keep at most one viewport operation in flight. Scroll events arriving
    /// while AX moves are running accumulate for the next frame instead of
    /// building an unbounded FIFO backlog behind a slow application.
    private func scheduleScrollFlush() {
        guard !scrollFlushScheduled, !pendingScrolls.isEmpty, !shuttingDown else { return }
        scrollFlushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
            let deltas = self.pendingScrolls
            self.pendingScrolls.removeAll(keepingCapacity: true)
            let context = Context.capture()
            self.queue.async {
                for (workspace, delta) in deltas {
                    self.shiftViewport(on: workspace, by: delta, context: context)
                }
                DispatchQueue.main.async {
                    self.scrollFlushScheduled = false
                    if !self.pendingScrolls.isEmpty { self.scheduleScrollFlush() }
                }
            }
        }
    }

    /// Release only visible desktops before another window manager takes over.
    func release(completion: @escaping () -> Void) {
        precondition(Thread.isMainThread)
        let context = Context.capture()
        queue.async {
            for (key, strip) in Array(self.strips) where self.isCurrent(strip) {
                self.strips.removeValue(forKey: key)
                self.restore(strip.entries.map(\.saved), context: context)
            }
            self.publish()
            DispatchQueue.main.async(execute: completion)
        }
    }

    /// RoomEngine applies the room's saved geometry once. If continuous tiling
    /// is enabled on the target Space, hold that workspace while the room is
    /// laid out, then adopt the resulting frames as the tiler's new baseline.
    func releaseForRoomActivation(_ room: Room, completion: @escaping (Bool) -> Void) {
        precondition(Thread.isMainThread)
        let context = Context.capture()
        let target = roomWorkspace(room, context: context)
        queue.async {
            guard AXIsProcessTrusted() else {
                self.report("Room activation needs Accessibility permission.")
                DispatchQueue.main.async { completion(false) }
                return
            }
            guard self.loadRecovery(context) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            if let target {
                let profile = TilingWorkspaceProfiles.profile(for: target.key,
                    in: TilingWorkspaceProfiles.load())
                if profile.mode == .tiling { self.roomHandoffs[room.id] = target.workspace }
            }
            for (key, strip) in Array(self.strips) where self.isCurrent(strip) {
                self.strips.removeValue(forKey: key)
                self.arrangements[key] = strip.arrangement
                self.restore(strip.entries.map(\.saved), context: context)
            }
            self.publish()
            DispatchQueue.main.async { completion(true) }
        }
    }

    func willTile(_ room: Room) -> Bool {
        precondition(Thread.isMainThread)
        let context = Context.capture()
        guard let target = roomWorkspace(room, context: context) else { return false }
        return TilingWorkspaceProfiles.profile(for: target.key,
            in: TilingWorkspaceProfiles.load()).mode == .tiling
    }

    func resumeAfterRoomActivation(_ room: Room) {
        precondition(Thread.isMainThread)
        let context = Context.capture()
        guard let target = roomWorkspace(room, context: context) else {
            queue.async { self.roomHandoffs.removeValue(forKey: room.id) }
            return
        }
        let profile = TilingWorkspaceProfiles.profile(for: target.key, in: TilingWorkspaceProfiles.load())
        queue.async {
            let handoff = self.roomHandoffs.removeValue(forKey: room.id)
            guard profile.mode == .tiling, handoff == target.workspace,
                  self.isDesktopCurrent(target.key.spaceID, display: target.display) else { return }
            self.activate(workspace: target.workspace, display: target.display,
                          space: target.key.spaceID, profile: profile, context: context)
        }
    }

    private func roomWorkspace(_ room: Room, context: Context) -> (key: TilingWorkspaceKey, workspace: CanvasWorkspace, display: Display)? {
        let display: Display?
        if let uuid = room.displayUUID {
            display = context.displays.first(where: { $0.uuid == uuid })
                ?? context.displays.first(where: { $0.bounds.contains(context.pointer) })
                ?? context.displays.first
        } else {
            display = context.displays.first(where: { $0.bounds.contains(context.pointer) }) ?? context.displays.first
        }
        guard let display, let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else { return nil }
        return (TilingWorkspaceKey(displayUUID: display.uuid, spaceID: space),
                CanvasWorkspace(displayID: display.id, spaceID: space), display)
    }

    func shutdown(completion: @escaping () -> Void) {
        shuttingDown = true
        timer?.invalidate()
        timer = nil
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        let context = Context.capture()
        queue.async {
            self.releaseAll(context)
            DispatchQueue.main.async(execute: completion)
        }
    }

    private func shiftViewport(on workspace: CanvasWorkspace, by delta: CGFloat, context: Context) {
        guard let strip = strips[workspace], isCurrent(strip), !strip.widths.isEmpty else { return }
        let geometry = CanvasLayout.Geometry(area: strip.display.area, rows: 2)
        strip.viewport = CanvasLayout.clampViewport(strip.viewport + delta, widths: strip.widths, viewport: geometry.contentWidth)
        teleport(strip, context: context)
    }

    private func fitViewport(_ strip: Strip) {
        guard strip.layout == .canvas else { return }
        guard let index = strip.entries.firstIndex(where: { $0.saved.id == strip.selected }) else { return }
        let geometry = CanvasLayout.Geometry(area: strip.display.area, rows: 2)
        guard let slot = CanvasLayout.slot(index: index, columns: strip.columns) else { return }
        strip.viewport = CanvasLayout.fitViewport(
            index: slot.column,
            widths: strip.widths,
            geometry: geometry,
            current: strip.viewport
        )
    }

    private func retile(_ strip: Strip) {
        if strip.layout != .canvas {
            strip.columns = []
            strip.widths = []
            if !strip.entries.contains(where: { $0.saved.id == strip.selected }) {
                strip.selected = strip.entries.first?.saved.id
            }
            return
        }
        strip.arrangement.synchronize(strip.entries.map { $0.saved.id })
        let indices = Dictionary(uniqueKeysWithValues: strip.entries.enumerated().map { ($0.element.saved.id, $0.offset) })
        strip.columns = strip.arrangement.columns.map { column in
            CanvasLayout.Column(windows: column.windows.compactMap { indices[$0] }, rows: column.halfHeight ? 2 : 1)
        }
        strip.widths = strip.columns.map { column in
            column.windows.reduce(strip.defaultWidth) { max($0, strip.entries[$1].minimumWidth) }
        }
        if !strip.entries.contains(where: { $0.saved.id == strip.selected }) {
            strip.selected = strip.entries.first?.saved.id
        }
    }

    /// Recommit every window to its cell, focused first (the one the user is
    /// watching), then on-screen left-to-right, then parked slivers. Unchanged
    /// origins skip their AX round-trip entirely (ScrollWM measurement: an AX
    /// move costs ~0.4ms cross-process, so skips dominate on large strips).
    private func teleport(_ strip: Strip, context: Context, negotiationPass: Int = 0) {
        guard isCurrent(strip) else { return }
        guard strip.layout == .canvas else {
            teleportRegular(strip, context: context)
            return
        }
        guard !strip.widths.isEmpty else { return }
        let geometry = CanvasLayout.Geometry(area: strip.display.area, rows: 2)
        strip.viewport = CanvasLayout.clampViewport(strip.viewport, widths: strip.widths, viewport: geometry.contentWidth)
        let others = context.displays.filter { $0.id != strip.display.id }.map(\.bounds)

        func placement(at index: Int) -> CanvasLayout.Placement {
            guard let slot = CanvasLayout.slot(index: index, columns: strip.columns) else {
                return CanvasLayout.Placement(frame: .null, parked: nil)
            }
            return CanvasLayout.placement(
                column: slot.column,
                row: slot.row,
                widths: strip.widths,
                geometry: geometry,
                viewport: strip.viewport,
                otherDisplays: others,
                rows: strip.columns[slot.column].rows
            )
        }

        let selectedIndex = strip.entries.firstIndex(where: { $0.saved.id == strip.selected })
        var order = strip.entries.indices.filter { $0 != selectedIndex }
        order.sort { lhs, rhs in
            let left = placement(at: lhs)
            let right = placement(at: rhs)
            switch (left.parked, right.parked) {
            case (nil, nil): return left.frame.minX < right.frame.minX
            case (nil, .some): return true
            case (.some, nil): return false
            default: return lhs < rhs
            }
        }
        if let selectedIndex { order.insert(selectedIndex, at: 0) }

        var needsRetile = false
        for index in order {
            guard isCurrent(strip) else { strip.suspended = true; return }
            let entry = strip.entries[index]
            guard CanvasWindowAccess.id(entry.window) == entry.saved.id else { continue }
            guard let column = CanvasLayout.slot(index: index, columns: strip.columns)?.column else { continue }
            let target = placement(at: index)
            if let last = entry.lastFrame,
               abs(last.minX - target.frame.minX) < 0.5, abs(last.minY - target.frame.minY) < 0.5,
               abs(last.width - target.frame.width) < 0.5, abs(last.height - target.frame.height) < 0.5 {
                continue
            }
            guard CanvasWindowAccess.eligible(entry.window),
                  SpaceManagementService.desktops(forWindow: entry.saved.id) == [strip.space]
            else { continue }
            let result = CanvasWindowAccess.applyCanvasFrame(target.frame, window: entry.window) { self.isCurrent(strip) }
            let accepted = result.accepted
            if let actual = result.actual {
                entry.lastFrame = accepted && CanvasFrameApplication.fitsSize(actual.size, target.frame.size)
                    && abs(actual.minX - target.frame.minX) < 3 && abs(actual.minY - target.frame.minY) < 3 ? target.frame : nil
                // Negotiate all sizes BEFORE recomputing origins: mutating column
                // widths in the placement loop left earlier windows misaligned.
                if result.confirmedWidthConstraint {
                    entry.minimumWidth = actual.width
                    needsRetile = true
                }
                if strip.arrangement.isHalfHeight(entry.saved.id) && result.confirmedHeightConstraint {
                    strip.arrangement.setFullHeight(entry.saved.id)
                    needsRetile = true
                    report("This window needs full height; Canvas kept it in its own column.")
                } else if strip.arrangement.isHalfHeight(entry.saved.id) && actual.height > target.frame.height + 3 {
                    report("Canvas could not confirm half height. The choice is kept; try the shortcut again when the app responds.")
                }
                if !accepted { entry.lastFrame = nil }
            }
            if !accepted {
                logger.notice("Canvas window \(entry.saved.id) rejected its cell frame")
            }
        }
        if needsRetile {
            retile(strip)
            fitViewport(strip)
            if negotiationPass < 2 {
                teleport(strip, context: context, negotiationPass: negotiationPass + 1)
            }
        }
        // The minimap bar follows every placement pass: keyboard navigation,
        // continuous scroll and retiles all end here.
        publish()
    }

    /// Apply one of the RoomTiler algorithms to the live desktop. The same pure
    /// geometry is used by the settings preview, so future-window behavior is
    /// visible before the layout is enabled.
    private func teleportRegular(_ strip: Strip, context: Context) {
        guard isCurrent(strip), let roomLayout = strip.layout.roomLayout else { return }
        let selectedIndex = strip.entries.firstIndex(where: { $0.saved.id == strip.selected })
        let frames = TilingLayoutGeometry.frames(kind: strip.layout, count: strip.entries.count,
            in: strip.display.area, selectedIndex: selectedIndex)
        guard frames.count == strip.entries.count else { return }

        var order = Array(strip.entries.indices)
        if roomLayout == .monocle {
            // All monocle frames overlap; raise the selected one last so it is
            // the visible card without minimizing windows or losing state.
            if let selected = strip.entries.firstIndex(where: { $0.saved.id == strip.selected }) {
                order.removeAll { $0 == selected }
                order.append(selected)
            }
        } else if let selected = strip.entries.firstIndex(where: { $0.saved.id == strip.selected }) {
            order.removeAll { $0 == selected }
            order.insert(selected, at: 0)
        }

        for index in order {
            guard isCurrent(strip) else { strip.suspended = true; return }
            let entry = strip.entries[index]
            guard CanvasWindowAccess.id(entry.window) == entry.saved.id,
                  CanvasWindowAccess.eligible(entry.window),
                  SpaceManagementService.desktops(forWindow: entry.saved.id) == [strip.space]
            else { continue }
            let target = frames[index]
            if let last = entry.lastFrame,
               abs(last.minX - target.minX) < 0.5, abs(last.minY - target.minY) < 0.5,
               abs(last.width - target.width) < 0.5, abs(last.height - target.height) < 0.5 {
                continue
            }
            let result = CanvasWindowAccess.applyCanvasFrame(target, window: entry.window) { self.isCurrent(strip) }
            if let actual = result.actual,
               result.accepted, CanvasFrameApplication.fitsSize(actual.size, target.size),
               abs(actual.minX - target.minX) < 3, abs(actual.minY - target.minY) < 3 {
                entry.lastFrame = target
            } else {
                entry.lastFrame = nil
                if !result.accepted {
                    logger.notice("Tiling window \(entry.saved.id) rejected its frame")
                }
            }
        }
        if roomLayout == .monocle, let selectedIndex,
           strip.entries.indices.contains(selectedIndex) {
            CanvasWindowAccess.raise(strip.entries[selectedIndex].window)
        }
        publish()
    }

    private func focusSelected(_ strip: Strip) {
        guard isCurrent(strip),
              let entry = strip.entries.first(where: { $0.saved.id == strip.selected }),
              CanvasWindowAccess.eligible(entry.window) else { return }
        CanvasWindowAccess.raise(entry.window)
        if !CanvasWindowAccess.focus(entry.window, pid: entry.saved.pid, stillCurrent: { self.isCurrent(strip) }) {
            logger.notice("Canvas focus not confirmed for selected window \(entry.saved.id)")
        }
        strip.lastNavigation = ProcessInfo.processInfo.systemUptime
    }

    private func targetDisplay(_ context: Context, focused: CGWindowID?) -> Display? {
        if let focused, let strip = strips.values.first(where: { self.isCurrent($0) && $0.entries.contains(where: { $0.saved.id == focused }) }) {
            return context.displays.first(where: { $0.id == strip.display.id })
        }
        if let focused, let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, focused) as? [[String: Any]])?.first,
           let raw = info[kCGWindowBounds as String] as? [String: Any],
           let frame = CGRect(dictionaryRepresentation: raw as CFDictionary) {
            return context.displays.max { Self.area($0.bounds.intersection(frame)) < Self.area($1.bounds.intersection(frame)) }
        }
        return context.displays.first(where: { $0.bounds.contains(context.pointer) }) ?? context.displays.first
    }

    private static func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }

    private func discover(_ context: Context, on display: Display, space: UInt64,
                          diagnose: Bool = false, reconcile: Bool = false) -> [Entry] {
        guard let allInfos = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        // Stage 1 — WindowServer data only: display attribution first (pure
        // geometry), then visibility. SkyLight membership is asked only for
        // non-visible windows already attributed to this display; asking for
        // every window of the system on every 0.8 s observer pass flooded the
        // Canvas queue and lagged the strip.
        struct Candidate {
            let id: CGWindowID
            let pid: pid_t
            let frame: CGRect
            let layer: Int
            let owner: String
        }
        var candidates: [Candidate] = []
        var issues: [(String, String)] = []
        for info in allInfos {
            guard let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let raw = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: raw as CFDictionary),
                  frame.width > 0, frame.height > 0,
                  context.apps[pid] != nil, !context.hiddenPIDs.contains(pid) else { continue }
            let documentSized = frame.width > 80 && frame.height > 80 && (info[kCGWindowLayer as String] as? Int) == 0
            guard context.displays.max(by: { Self.area($0.bounds.intersection(frame)) < Self.area($1.bounds.intersection(frame)) })?.id == display.id else {
                if diagnose, documentSized {
                    issues.append(("\((info[kCGWindowOwnerName as String] as? String ?? String(pid))) #\(id)", "Mostly on another display"))
                }
                continue
            }
            if (info[kCGWindowIsOnscreen as String] as? Bool) == true
                || SpaceManagementService.desktops(forWindow: id)?.contains(space) == true {
                candidates.append(Candidate(id: id, pid: pid, frame: frame, layer: info[kCGWindowLayer as String] as? Int ?? 0,
                    owner: info[kCGWindowOwnerName as String] as? String ?? String(pid)))
            } else if diagnose, documentSized {
                issues.append(("\((info[kCGWindowOwnerName as String] as? String ?? String(pid))) #\(id)", "Desktop membership unavailable"))
            }
        }
        // Stage 2 — Accessibility for the applications that own candidates,
        // never for every running app. Reconciliation (Electron inventory
        // initialization) runs only on explicit commands.
        var expectedByPID: [pid_t: Set<CGWindowID>] = [:]
        for candidate in candidates where candidate.layer == 0 && candidate.frame.width > 80 && candidate.frame.height > 80 {
            expectedByPID[candidate.pid, default: []].insert(candidate.id)
        }
        var windows: [CGWindowID: AXUIElement] = [:]
        for pid in Set(candidates.map(\.pid)) {
            for window in CanvasWindowAccess.windows(pid: pid, expectedWindowIDs: expectedByPID[pid] ?? [], reconcile: reconcile) {
                if let id = CanvasWindowAccess.id(window) { windows[id] = window }
            }
        }
        // Stage 3 — eligibility, journal ghosts and capture.
        var supported = 0
        let managed = Set(strips.values.flatMap { $0.entries.map { $0.saved.id } })
        let entries: [Entry] = candidates.compactMap { candidate in
            let id = candidate.id
            let pid = candidate.pid
            let window = windows[id]
            // Standard AX windows may have a nonzero WindowServer layer (e.g.
            // always-on-top apps). The old layer-zero rule silently lost them.
            guard candidate.layer == 0 || window.map(CanvasWindowAccess.eligible) == true else { return nil }
            if managed.contains(id) { supported += 1; return nil }
            let label = "\(candidate.owner) #\(id)"
            func exclude(_ reason: String) {
                if diagnose { issues.append((label, reason)) }
            }
            guard let launchedAt = context.apps[pid], let window else {
                exclude("Window unavailable through Accessibility"); return nil
            }
            if let reason = CanvasWindowAccess.exclusionReason(window) { exclude(reason); return nil }
            let spaces = SpaceManagementService.desktops(forWindow: id)
            guard spaces == [space] else {
                exclude(spaces?.count ?? 0 > 1 ? "Window assigned to several desktops" : "Desktop membership unavailable")
                return nil
            }
            if let record = saved[id] {
                // A window already sitting at its journaled frame has nothing
                // awaiting restoration; adopt it instead of excluding it.
                if let current = CanvasWindowAccess.frame(window), CanvasFrameApplication.restored(current, record.frame) {
                    saved.removeValue(forKey: id)
                } else {
                    exclude("Window awaiting Canvas restoration"); return nil
                }
            }
            guard let original = CanvasWindowAccess.frame(window) else { exclude("Window frame unavailable"); return nil }
            supported += 1
            return Entry(saved: SavedWindow(id: id, pid: pid, launchedAt: launchedAt, frame: original, space: space), window: window)
        }
        if diagnose {
            let count = supported
            let exclusions = issues
            DispatchQueue.main.async {
                self.inventoryMessage = ([String(format: localizedString("Canvas: %d supported window(s), %d excluded."), count, exclusions.count)]
                    + exclusions.map { "\($0.0): \(localizedString($0.1))" }).joined(separator: "\n")
            }
        }
        return entries.sorted {
            if abs($0.saved.frame.minX - $1.saved.frame.minX) > 8 {
                return $0.saved.frame.minX < $1.saved.frame.minX
            }
            return $0.saved.frame.minY < $1.saved.frame.minY
        }
    }

    private func isCurrent(_ strip: Strip) -> Bool {
        SpaceManagementService.userDesktop(onDisplay: strip.display.uuid) == strip.space
    }

    private func tick() {
        guard !tickPending, !shuttingDown else { return }
        tickPending = true
        refreshCurrentWorkspace()
        let context = Context.capture()
        queue.async {
            defer { DispatchQueue.main.async { self.tickPending = false } }
            guard AXIsProcessTrusted(), self.loadRecovery(context) else { return }
            let focused = CanvasWindowAccess.focusedID(pid: context.frontmostPID)
            for (workspace, strip) in Array(self.strips) {
                let currentDisplay = context.displays.first(where: { $0.id == workspace.displayID })
                let state = CanvasWorkspacePolicy.state(ownedSpace: strip.space,
                    currentSpace: SpaceManagementService.userDesktop(onDisplay: strip.display.uuid),
                    displayConnected: currentDisplay != nil)
                switch state {
                case .disconnected:
                    self.strips.removeValue(forKey: workspace)
                    self.restore(strip.entries.map(\.saved), context: context)
                    continue
                case .suspended:
                    strip.suspended = true
                    continue
                case .active: break
                }
                guard let display = currentDisplay else { continue }
                let workspaceKey = TilingWorkspaceKey(displayUUID: display.uuid, spaceID: strip.space)
                let profile = TilingWorkspaceProfiles.profile(for: workspaceKey,
                    in: TilingWorkspaceProfiles.load())
                guard profile.mode == .tiling else {
                    self.strips.removeValue(forKey: workspace)
                    self.arrangements[workspace] = strip.arrangement
                    self.restore(strip.entries.map(\.saved), context: context)
                    continue
                }
                let resumed = strip.suspended
                var changed = resumed || display.area != strip.display.area || strip.layout != profile.layout
                if strip.layout != profile.layout {
                    strip.layout = profile.layout
                    strip.viewport = 0
                }
                strip.display = display
                strip.suspended = false
                if changed {
                    strip.entries.forEach { $0.lastFrame = nil }
                    strip.lastNavigation = ProcessInfo.processInfo.systemUptime
                }
                strip.entries.removeAll { entry in
                    let dead = context.apps[entry.saved.pid] != entry.saved.launchedAt
                        || (CGWindowListCopyWindowInfo(.optionIncludingWindow, entry.saved.id) as? [[String: Any]])?.isEmpty == true
                    // An empty list during a Space animation is not a window move.
                    let moved = SpaceManagementService.desktops(forWindow: entry.saved.id).map {
                        !$0.isEmpty && !$0.contains(strip.space)
                    } ?? false
                    if dead || moved {
                        self.saved.removeValue(forKey: entry.saved.id)
                        changed = true
                        return true
                    }
                    return false
                }
                let additions = self.discover(context, on: display, space: strip.space)
                for entry in additions { self.saved[entry.saved.id] = entry.saved }
                if changed || !additions.isEmpty {
                    guard self.persist() else { continue }
                }
                if !additions.isEmpty {
                    strip.entries.append(contentsOf: additions)
                    changed = true
                }
                if changed {
                    self.retile(strip)
                    if !resumed { self.fitViewport(strip) }
                }
                if ProcessInfo.processInfo.systemUptime - strip.lastNavigation > 1,
                   let focused, focused != strip.selected, strip.entries.contains(where: { $0.saved.id == focused }) {
                    strip.selected = focused
                    self.fitViewport(strip)
                    changed = true
                }
                if strip.entries.isEmpty { self.strips.removeValue(forKey: workspace) }
                else if changed { self.teleport(strip, context: context) }
            }
            // A profile can be enabled on a Space before it has windows. Keep
            // polling every connected screen and adopt newly-created windows.
            for display in context.displays {
                guard let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else { continue }
                let workspace = CanvasWorkspace(displayID: display.id, spaceID: space)
                guard self.strips[workspace] == nil,
                      !self.roomHandoffs.values.contains(workspace) else { continue }
                let key = TilingWorkspaceKey(displayUUID: display.uuid, spaceID: space)
                let profile = TilingWorkspaceProfiles.profile(for: key, in: TilingWorkspaceProfiles.load())
                guard profile.mode == .tiling else { continue }
                self.activate(workspace: workspace, display: display, space: space,
                              profile: profile, context: context)
            }
            // Retry orphaned records on visible desktops, never records still
            // owned by an active or suspended strip.
            let owned = Set(self.strips.values.flatMap { $0.entries.map { $0.saved.id } })
            let visible = Set(context.displays.compactMap { SpaceManagementService.userDesktop(onDisplay: $0.uuid) })
            let pending = self.saved.values.filter {
                !owned.contains($0.id) && (visible.contains($0.space) || context.apps[$0.pid] != $0.launchedAt)
            }
            if !pending.isEmpty { self.restore(Array(pending), context: context) }
            self.publish()
        }
    }

    private func loadRecovery(_ context: Context) -> Bool {
        guard !recoveryLoaded else { return true }
        do {
            if FileManager.default.fileExists(atPath: restoreURL.path) {
                let records = try JSONDecoder().decode([SavedWindow].self, from: Data(contentsOf: restoreURL))
                for record in records { saved[record.id] = record }
                restore(records, context: context)
                // Keep inactive-desktop records for retry on return without
                // blocking Canvas commands on the other desktops.
            }
            recoveryLoaded = true
            return true
        } catch {
            report("Canvas could not read its restore file.")
            return false
        }
    }

    private func releaseAll(_ context: Context) {
        strips.removeAll()
        restore(Array(saved.values), context: context)
        publish()
    }

    /// Put every journaled window back to its EXACT original frame — position
    /// and size, the user's quarter-snapped layout included — and verify the
    /// result instead of trusting the AX reply.
    private func restore(_ records: [SavedWindow], context: Context) {
        var windowCache: [pid_t: [AXUIElement]] = [:]
        let visibleSpaces = Set(context.displays.compactMap { SpaceManagementService.userDesktop(onDisplay: $0.uuid) })
        for record in records {
            guard context.apps[record.pid] == record.launchedAt else { saved.removeValue(forKey: record.id); continue }
            guard visibleSpaces.contains(record.space) else { continue }
            if windowCache[record.pid] == nil { windowCache[record.pid] = CanvasWindowAccess.windows(pid: record.pid) }
            guard let window = windowCache[record.pid]?.first(where: { CanvasWindowAccess.id($0) == record.id }) else {
                // Keep inaccessible windows for another attempt; only discard
                // when WindowServer confirms that the ID no longer exists.
                let infos = CGWindowListCopyWindowInfo(.optionIncludingWindow, record.id) as? [[String: Any]]
                if infos?.isEmpty == true { saved.removeValue(forKey: record.id) }
                continue
            }
            if let spaces = SpaceManagementService.desktops(forWindow: record.id),
               !spaces.isEmpty, !spaces.contains(record.space) {
                // macOS can reassign windows parked beyond the visible screen.
                // The original Space is visible here, so move it back before
                // restoring its exact saved frame.
                guard SpaceManagementService.restoreWindow(record.id, toDesktop: record.space) else { continue }
            }
            var frame = record.frame
            if !context.displays.contains(where: {
                $0.bounds.intersects(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 24))
            }), let display = context.displays.first {
                frame.size.width = min(frame.width, display.area.width)
                frame.size.height = min(frame.height, display.area.height)
                frame.origin = display.area.origin
            }
            guard context.displays.contains(where: {
                SpaceManagementService.userDesktop(onDisplay: $0.uuid) == record.space
            }) else { continue }
            AXUIElementSetMessagingTimeout(window, 0.5)
            var restored = false
            for attempt in 0..<3 {
                _ = CanvasWindowAccess.setFrame(frame, window: window)
                if let actual = CanvasWindowAccess.frame(window), CanvasFrameApplication.restored(actual, frame) {
                    restored = true
                    break
                }
                if attempt < 2 { Thread.sleep(forTimeInterval: 0.12) }
            }
            if restored {
                saved.removeValue(forKey: record.id)
            }
        }
        _ = persist()
        if records.contains(where: { saved[$0.id] != nil }) {
            report("Canvas restoration is pending. Return to the affected desktop to finish restoring its windows.")
        }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            try FileManager.default.createDirectory(at: restoreURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Array(saved.values)).write(to: restoreURL, options: .atomic)
            return true
        } catch {
            report("Canvas could not save original window positions.")
            return false
        }
    }

    private func publish() {
        let canvasStrips = strips.values.filter { $0.layout == .canvas }
        let workspaces = Set(canvasStrips.map { CanvasWorkspace(displayID: $0.display.id, spaceID: $0.space) })
        let ids = Set(canvasStrips.filter { isCurrent($0) }.map { $0.display.id })
        var snapshots: [CGDirectDisplayID: CanvasMinimap.Model] = [:]
        for strip in canvasStrips where isCurrent(strip) && !strip.widths.isEmpty {
            let geometry = CanvasLayout.Geometry(area: strip.display.area, rows: 2)
            if let model = CanvasMinimap.model(
                displayID: strip.display.id,
                widths: strip.widths,
                columns: strip.columns,
                windowIDs: strip.entries.map { $0.saved.id },
                selected: strip.selected,
                viewport: strip.viewport,
                contentWidth: geometry.contentWidth
            ) {
                snapshots[strip.display.id] = model
            }
        }
        DispatchQueue.main.async {
            self.knownWorkspaces = workspaces
            if self.minimaps != snapshots { self.minimaps = snapshots }
            if self.activeDisplayIDs != ids {
                self.activeDisplayIDs = ids
                NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
            }
            self.refreshCurrentWorkspace()
        }
    }

    private func report(_ key: String) {
        logger.error("\(key, privacy: .public)")
        DispatchQueue.main.async { self.message = localizedString(key) }
    }
}
