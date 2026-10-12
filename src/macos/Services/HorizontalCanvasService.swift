import AppKit
import Combine
import OSLog

enum CanvasAction: String {
    case toggle, previous, next, above, below, fullHeight, halfHeight, restore, inspect
}

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
        var lastNavigation: TimeInterval = 0
        var suspended = false
        init(display: Display, space: UInt64, defaultWidth: CGFloat) {
            self.display = display
            self.space = space
            self.defaultWidth = defaultWidth
        }
    }

    private let queue = DispatchQueue(label: "pk.windows-management.canvas", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.mondary.PKwindowsManagement", category: "Canvas")
    private var strips: [CanvasWorkspace: Strip] = [:]
    private var knownWorkspaces: Set<CanvasWorkspace> = [] // main thread snapshot
    private var saved: [CGWindowID: SavedWindow] = [:]
    private var recoveryLoaded = false
    private var timer: Timer?
    private var tickPending = false // main thread only
    private var shuttingDown = false // main thread only
    private var spaceObserver: NSObjectProtocol?
    private let restoreURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PKwindowsManagement/CanvasRestore.json")

    func start() {
        precondition(Thread.isMainThread)
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in self?.tick() }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick() }
        tick()
    }

    func perform(_ action: CanvasAction) {
        precondition(Thread.isMainThread)
        guard !shuttingDown else { return }
        message = ""
        let context = Context.capture()
        queue.async {
            guard AXIsProcessTrusted() else { self.report("Canvas needs Accessibility permission."); return }
            if action == .inspect {
                guard let display = self.targetDisplay(context, focused: CanvasWindowAccess.focusedID(pid: context.frontmostPID)),
                      let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else { return }
                _ = self.discover(context, on: display, space: space, diagnose: true)
                return
            }
            guard self.loadRecovery(context) else { return }
            if action == .restore { self.releaseAll(context); return }
            let focused = CanvasWindowAccess.focusedID(pid: context.frontmostPID)
            let display = self.targetDisplay(context, focused: focused)
            guard let display else { self.report("No display available for Canvas."); return }
            guard let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else {
                self.report("Canvas requires a normal desktop."); return
            }
            let workspace = CanvasWorkspace(displayID: display.id, spaceID: space)
            if action == .toggle {
                if let strip = self.strips.removeValue(forKey: workspace) {
                    self.restore(strip.entries.map(\.saved), context: context)
                    self.publish()
                    return
                }
                let entries = self.discover(context, on: display, space: space, diagnose: true)
                guard !entries.isEmpty else { self.report("No compatible windows on this desktop."); return }
                // Journal before moving even the first window.
                for entry in entries { self.saved[entry.saved.id] = entry.saved }
                guard self.persist() else { return }
                let geometry = CanvasLayout.Geometry(area: display.area, rows: 2)
                let strip = Strip(
                    display: display,
                    space: space,
                    defaultWidth: geometry.defaultColumnWidth(
                        columns: CanvasLayout.preferredColumns(forAreaWidth: display.area.width)
                    )
                )
                strip.entries = entries
                self.retile(strip)
                strip.selected = entries.first(where: { $0.saved.id == focused })?.saved.id ?? entries.first?.saved.id
                self.strips[workspace] = strip
                self.fitViewport(strip)
                self.teleport(strip, context: context)
                self.focusSelected(strip)
                self.publish()
            } else if let strip = self.strips[workspace], self.isCurrent(strip) {
                guard !strip.entries.isEmpty, !strip.widths.isEmpty else { return }
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

    /// Continuous horizontal/Option scroll. Never read the worker-owned strips on
    /// the event-tap thread; knownWorkspaces is the main-thread snapshot.
    func scroll(rawDelta: CGFloat, location: CGPoint) -> Bool {
        precondition(Thread.isMainThread)
        guard !shuttingDown else { return false }
        let context = Context.capture()
        guard let display = context.displays.first(where: { $0.bounds.contains(location) }),
              let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else { return false }
        let workspace = CanvasWorkspace(displayID: display.id, spaceID: space)
        guard knownWorkspaces.contains(workspace) else { return false }
        queue.async { self.shiftViewport(on: workspace, by: -rawDelta, context: context) }
        return true
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
        guard isCurrent(strip), !strip.widths.isEmpty else { return }
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
            guard CanvasWindowAccess.id(entry.window) == entry.saved.id,
                  CanvasWindowAccess.eligible(entry.window),
                  SpaceManagementService.desktops(forWindow: entry.saved.id) == [strip.space]
            else { continue }
            guard let column = CanvasLayout.slot(index: index, columns: strip.columns)?.column else { continue }
            let target = placement(at: index)
            if let last = entry.lastFrame,
               abs(last.minX - target.frame.minX) < 0.5, abs(last.minY - target.frame.minY) < 0.5,
               abs(last.width - target.frame.width) < 0.5, abs(last.height - target.frame.height) < 0.5 {
                continue
            }
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

    private func discover(_ context: Context, on display: Display, space: UInt64, diagnose: Bool = false) -> [Entry] {
        guard let allInfos = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        // On-screen alone is not authoritative during occlusion/Space changes.
        // Include windows on this desktop, then apply AX/minimized/hidden filters.
        let infos = allInfos.filter { info in
            guard let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  context.apps[pid] != nil, !context.hiddenPIDs.contains(pid) else { return false }
            return (info[kCGWindowIsOnscreen as String] as? Bool) == true
                || SpaceManagementService.desktops(forWindow: id)?.contains(space) == true
        }
        var windows: [CGWindowID: AXUIElement] = [:]
        let pids = Set(infos.compactMap { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value })
        for pid in pids where context.apps[pid] != nil {
            let expected = Set(infos.compactMap { info -> CGWindowID? in
                guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                      (info[kCGWindowLayer as String] as? Int) == 0,
                      let raw = info[kCGWindowBounds as String] as? [String: Any],
                      let frame = CGRect(dictionaryRepresentation: raw as CFDictionary),
                      frame.width > 80, frame.height > 80 else { return nil }
                return (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value
            })
            for window in CanvasWindowAccess.windows(pid: pid, expectedWindowIDs: expected) {
                if let id = CanvasWindowAccess.id(window) { windows[id] = window }
            }
        }
        var issues: [(String, String)] = []
        var supported = 0
        let managed = Set(strips.values.flatMap { $0.entries.map { $0.saved.id } })
        let entries: [Entry] = infos.compactMap { info in
            guard let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                   let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                   let raw = info[kCGWindowBounds as String] as? [String: Any],
                   let frame = CGRect(dictionaryRepresentation: raw as CFDictionary),
                   frame.width > 0, frame.height > 0,
                   context.displays.max(by: { Self.area($0.bounds.intersection(frame)) < Self.area($1.bounds.intersection(frame)) })?.id == display.id
            else { return nil }
            let window = windows[id]
            // Standard AX windows may have a nonzero WindowServer layer (e.g.
            // always-on-top apps). The old layer-zero rule silently lost them.
            guard (info[kCGWindowLayer as String] as? Int) == 0 || window.map(CanvasWindowAccess.eligible) == true else { return nil }
            if managed.contains(id) { supported += 1; return nil }
            let label = "\(info[kCGWindowOwnerName as String] as? String ?? String(pid)) #\(id)"
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
            guard saved[id] == nil else { exclude("Window awaiting Canvas restoration"); return nil }
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
                let resumed = strip.suspended
                var changed = resumed || display.area != strip.display.area
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
            if let spaces = SpaceManagementService.desktops(forWindow: record.id), !spaces.isEmpty, !spaces.contains(record.space) {
                saved.removeValue(forKey: record.id)
                continue
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
            if CanvasWindowAccess.setFrame(frame, window: window),
               let actual = CanvasWindowAccess.frame(window),
               abs(actual.minX - frame.minX) < 3, abs(actual.minY - frame.minY) < 3,
               abs(actual.width - frame.width) < 3, abs(actual.height - frame.height) < 3 {
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
        let workspaces = Set(strips.keys)
        let ids = Set(strips.values.filter { isCurrent($0) }.map { $0.display.id })
        DispatchQueue.main.async {
            self.knownWorkspaces = workspaces
            guard self.activeDisplayIDs != ids else { return }
            self.activeDisplayIDs = ids
            NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
        }
    }

    private func report(_ key: String) {
        logger.error("\(key, privacy: .public)")
        DispatchQueue.main.async { self.message = localizedString(key) }
    }
}
