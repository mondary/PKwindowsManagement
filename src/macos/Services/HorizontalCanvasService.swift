import AppKit
import Combine
import OSLog

enum CanvasAction: String {
    case toggle, previous, next, above, below, fullHeight, halfHeight, restore
}

/// Paneru-style scrolling grid of real AX windows (see docs/canvas-plan.md):
/// mixed one/two-row columns per display, a horizontally scrolling viewport,
/// off-screen columns parked as edge slivers, and an exact-restore journal.
/// All layout/AX work is serial and off the main thread; AppKit state is
/// captured on the main thread only.
final class HorizontalCanvasService: ObservableObject {
    static let shared = HorizontalCanvasService()
    static let stateDidChange = Notification.Name("PKCanvasStateDidChange")
    @Published private(set) var activeDisplayIDs: Set<CGDirectDisplayID> = []
    @Published private(set) var message = ""

    private struct Display {
        let id: CGDirectDisplayID
        let uuid: String
        let bounds: CGRect
        let area: CGRect
    }

    private struct Context {
        let displays: [Display]
        let apps: [pid_t: Date]
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
                $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }.reduce(into: [pid_t: Date]()) { result, app in
                if let date = app.launchDate { result[app.processIdentifier] = date }
            }
            let pointer = NSEvent.mouseLocation
            return Context(
                displays: displays,
                apps: apps,
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
        var halfHeight = false
        var minimumWidth: CGFloat = 0
        init(saved: SavedWindow, window: AXUIElement) {
            self.saved = saved
            self.window = window
        }
    }

    private final class Strip {
        let display: Display
        let space: UInt64
        let defaultWidth: CGFloat
        /// Column-major; each column has its own row count.
        var entries: [Entry] = []
        var columns: [CanvasLayout.Column] = []
        var widths: [CGFloat] = []
        var selected: CGWindowID?
        var viewport: CGFloat = 0
        var lastNavigation: TimeInterval = 0
        init(display: Display, space: UInt64, defaultWidth: CGFloat) {
            self.display = display
            self.space = space
            self.defaultWidth = defaultWidth
        }
    }

    private let queue = DispatchQueue(label: "pk.windows-management.canvas", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.mondary.PKwindowsManagement", category: "Canvas")
    private var strips: [CGDirectDisplayID: Strip] = [:]
    private var saved: [CGWindowID: SavedWindow] = [:]
    private var recoveryLoaded = false
    private var timer: Timer?
    private var tickPending = false // main thread only
    private var shuttingDown = false // main thread only
    private let restoreURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PKwindowsManagement/CanvasRestore.json")

    func start() {
        precondition(Thread.isMainThread)
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    func perform(_ action: CanvasAction) {
        precondition(Thread.isMainThread)
        guard !shuttingDown else { return }
        message = ""
        let context = Context.capture()
        queue.async {
            guard AXIsProcessTrusted() else { self.report("Canvas needs Accessibility permission."); return }
            guard self.loadRecovery(context) else { return }
            if action == .restore { self.releaseAll(context); return }
            let focused = CanvasWindowAccess.focusedID(pid: context.frontmostPID)
            let display = self.targetDisplay(context, focused: focused)
            guard let display else { self.report("No display available for Canvas."); return }
            if action == .toggle {
                if let strip = self.strips.removeValue(forKey: display.id) {
                    self.restore(strip.entries.map(\.saved), context: context)
                    self.publish()
                    return
                }
                guard let space = SpaceManagementService.userDesktop(onDisplay: display.uuid) else {
                    self.report("Canvas requires a normal desktop."); return
                }
                let entries = self.discover(context, on: display, space: space)
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
                self.strips[display.id] = strip
                self.fitViewport(strip)
                self.teleport(strip, context: context)
                self.focusSelected(strip)
                self.publish()
            } else if let strip = self.strips[display.id], self.isCurrent(strip) {
                guard !strip.entries.isEmpty, !strip.widths.isEmpty else { return }
                if action == .fullHeight || action == .halfHeight {
                    // Read actual focus now, rather than waiting for the periodic
                    // observer: a click followed by a shortcut must affect that window.
                    guard let focused,
                          let entry = strip.entries.first(where: { $0.saved.id == focused }) else { return }
                    strip.selected = focused
                    entry.halfHeight = action == .halfHeight
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
    /// the event-tap thread; the published display IDs are the main-thread snapshot.
    func scroll(rawDelta: CGFloat, location: CGPoint) -> Bool {
        precondition(Thread.isMainThread)
        guard !shuttingDown else { return false }
        let context = Context.capture()
        guard let id = context.displays.first(where: { $0.bounds.contains(location) })?.id,
              activeDisplayIDs.contains(id) else { return false }
        queue.async { self.shiftViewport(on: id, by: -rawDelta, context: context) }
        return true
    }

    /// Called before other window managers/Space actions, and on normal quit.
    func release(completion: @escaping () -> Void) {
        precondition(Thread.isMainThread)
        let context = Context.capture()
        queue.async {
            self.releaseAll(context)
            DispatchQueue.main.async(execute: completion)
        }
    }

    func shutdown(completion: @escaping () -> Void) {
        shuttingDown = true
        timer?.invalidate()
        timer = nil
        release(completion: completion)
    }

    private func shiftViewport(on displayID: CGDirectDisplayID, by delta: CGFloat, context: Context) {
        guard let strip = strips[displayID], isCurrent(strip), !strip.widths.isEmpty else { return }
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
        strip.columns = CanvasLayout.columns(halfHeight: strip.entries.map(\.halfHeight))
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
            let accepted = CanvasWindowAccess.setFrame(target.frame, window: entry.window)
            if let actual = CanvasWindowAccess.frame(entry.window) {
                entry.lastFrame = target.frame
                // Negotiate all sizes BEFORE recomputing origins: mutating column
                // widths in the placement loop left earlier windows misaligned.
                if actual.width > strip.widths[column] + 1 {
                    entry.minimumWidth = actual.width
                    needsRetile = true
                }
                if entry.halfHeight && actual.height > target.frame.height + 3 {
                    entry.halfHeight = false
                    needsRetile = true
                    report("This window needs full height; Canvas kept it in its own column.")
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
        AXUIElementPerformAction(entry.window, kAXRaiseAction as CFString)
        if !CanvasWindowAccess.focus(entry.window, pid: entry.saved.pid) {
            logger.notice("Canvas focus not confirmed for selected window \(entry.saved.id)")
        }
        strip.lastNavigation = ProcessInfo.processInfo.systemUptime
    }

    private func targetDisplay(_ context: Context, focused: CGWindowID?) -> Display? {
        if let focused, let strip = strips.values.first(where: { $0.entries.contains(where: { $0.saved.id == focused }) }) {
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

    private func discover(_ context: Context, on display: Display, space: UInt64) -> [Entry] {
        guard let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        var windows: [CGWindowID: AXUIElement] = [:]
        let pids = Set(infos.compactMap { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value })
        for pid in pids where context.apps[pid] != nil {
            for window in CanvasWindowAccess.windows(pid: pid) {
                if let id = CanvasWindowAccess.id(window) { windows[id] = window }
            }
        }
        return infos.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  self.saved[id] == nil,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let launchedAt = context.apps[pid], let window = windows[id],
                  CanvasWindowAccess.eligible(window), let frame = CanvasWindowAccess.frame(window),
                  frame.width > 0, frame.height > 0,
                  context.displays.max(by: { Self.area($0.bounds.intersection(frame)) < Self.area($1.bounds.intersection(frame)) })?.id == display.id,
                  SpaceManagementService.desktops(forWindow: id) == [space]
            else { return nil }
            return Entry(saved: SavedWindow(id: id, pid: pid, launchedAt: launchedAt, frame: frame, space: space), window: window)
        }.sorted {
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
            for (id, strip) in Array(self.strips) {
                guard let display = context.displays.first(where: { $0.id == id }),
                      display.area == strip.display.area, self.isCurrent(strip) else {
                    self.strips.removeValue(forKey: id)
                    self.restore(strip.entries.map(\.saved), context: context)
                    self.publish()
                    continue
                }
                var changed = false
                strip.entries.removeAll { entry in
                    let dead = context.apps[entry.saved.pid] != entry.saved.launchedAt
                        || CanvasWindowAccess.id(entry.window) != entry.saved.id
                    let moved = SpaceManagementService.desktops(forWindow: entry.saved.id).map { $0 != [strip.space] } ?? false
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
                    self.fitViewport(strip)
                }
                if ProcessInfo.processInfo.systemUptime - strip.lastNavigation > 1,
                   let focused, focused != strip.selected, strip.entries.contains(where: { $0.saved.id == focused }) {
                    strip.selected = focused
                    self.fitViewport(strip)
                    changed = true
                }
                if strip.entries.isEmpty { self.strips.removeValue(forKey: id); self.publish() }
                else if changed { self.teleport(strip, context: context) }
            }
        }
    }

    private func loadRecovery(_ context: Context) -> Bool {
        guard !recoveryLoaded else { return true }
        do {
            if FileManager.default.fileExists(atPath: restoreURL.path) {
                let records = try JSONDecoder().decode([SavedWindow].self, from: Data(contentsOf: restoreURL))
                for record in records { saved[record.id] = record }
                restore(records, context: context)
                guard saved.isEmpty else { report("Some Canvas windows still need restoration. Use Restore Canvas."); return false }
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
        for record in records {
            guard context.apps[record.pid] == record.launchedAt else { saved.removeValue(forKey: record.id); continue }
            if windowCache[record.pid] == nil { windowCache[record.pid] = CanvasWindowAccess.windows(pid: record.pid) }
            guard let window = windowCache[record.pid]?.first(where: { CanvasWindowAccess.id($0) == record.id }) else {
                // Keep inaccessible windows for another attempt; only discard
                // when WindowServer confirms that the ID no longer exists.
                let infos = CGWindowListCopyWindowInfo(.optionIncludingWindow, record.id) as? [[String: Any]]
                if infos?.isEmpty == true { saved.removeValue(forKey: record.id) }
                continue
            }
            if let spaces = SpaceManagementService.desktops(forWindow: record.id), spaces != [record.space] {
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
            if CanvasWindowAccess.setFrame(frame, window: window),
               let actual = CanvasWindowAccess.frame(window),
               abs(actual.minX - frame.minX) < 3, abs(actual.minY - frame.minY) < 3,
               abs(actual.width - frame.width) < 3, abs(actual.height - frame.height) < 3 {
                saved.removeValue(forKey: record.id)
            }
        }
        _ = persist()
        if !saved.isEmpty { report("Some Canvas windows still need restoration. Use Restore Canvas.") }
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
        let ids = Set(strips.keys)
        DispatchQueue.main.async {
            self.activeDisplayIDs = ids
            NotificationCenter.default.post(name: Self.stateDidChange, object: nil)
        }
    }

    private func report(_ key: String) {
        logger.error("\(key, privacy: .public)")
        DispatchQueue.main.async { self.message = localizedString(key) }
    }
}
