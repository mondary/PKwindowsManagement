import AppKit
import Combine
import OSLog

enum CanvasAction: String {
    case toggle, previous, next, restore
}

/// Opt-in management of real AX windows. All layout/AX work is serial and off
/// the main thread; the main-thread snapshot keeps AppKit out of that queue.
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
        let widthRatio: CGFloat

        static func capture() -> Context {
            precondition(Thread.isMainThread)
            let top = NSScreen.screens.first?.frame.maxY ?? 0
            let displays = NSScreen.screens.compactMap { screen -> Display? in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                      let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
                let visible = screen.visibleFrame
                return Display(id: id, uuid: CFUUIDCreateString(nil, uuid) as String,
                    bounds: CGDisplayBounds(id),
                    area: CGRect(x: visible.minX + 12, y: top - visible.maxY + 12,
                                 width: max(1, visible.width - 24), height: max(1, visible.height - 24)))
            }
            let apps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }.reduce(into: [pid_t: Date]()) { result, app in
                if let date = app.launchDate { result[app.processIdentifier] = date }
            }
            let pointer = NSEvent.mouseLocation
            return Context(displays: displays, apps: apps,
                frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                pointer: CGPoint(x: pointer.x, y: top - pointer.y),
                widthRatio: CGFloat(AppRuntime.shared.settings?.canvasWidthRatio ?? 0.65))
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
        var width: CGFloat
        init(saved: SavedWindow, window: AXUIElement, width: CGFloat) {
            self.saved = saved; self.window = window; self.width = width
        }
    }

    private final class Strip {
        let display: Display
        let space: UInt64
        var entries: [Entry]
        var selected: CGWindowID?
        var offset: CGFloat = 0
        var lastNavigation: TimeInterval = 0
        init(display: Display, space: UInt64, entries: [Entry]) {
            self.display = display; self.space = space; self.entries = entries
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
                let strip = Strip(display: display, space: space, entries: entries)
                strip.selected = entries.first(where: { $0.saved.id == focused })?.saved.id ?? entries.first?.saved.id
                self.strips[display.id] = strip
                self.revealSelected(strip)
                self.render(strip, context: context, focus: true)
                self.publish()
            } else if let strip = self.strips[display.id], self.isCurrent(strip) {
                guard !strip.entries.isEmpty else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let livePID = DispatchQueue.main.sync { NSWorkspace.shared.frontmostApplication?.processIdentifier }
                let liveFocus = CanvasWindowAccess.focusedID(pid: livePID)
                let baseline = now - strip.lastNavigation < 0.4 ? strip.selected : liveFocus
                let current = strip.entries.firstIndex(where: { $0.saved.id == baseline })
                    ?? strip.entries.firstIndex(where: { $0.saved.id == strip.selected }) ?? 0
                let index = min(max(0, current + (action == .next ? 1 : -1)), strip.entries.count - 1)
                strip.selected = strip.entries[index].saved.id
                strip.lastNavigation = now
                self.revealSelected(strip)
                self.render(strip, context: context, focus: true)
            }
        }
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

    private func targetDisplay(_ context: Context, focused: CGWindowID?) -> Display? {
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
            return Entry(saved: SavedWindow(id: id, pid: pid, launchedAt: launchedAt, frame: frame, space: space),
                         window: window, width: min(display.area.width, max(320, display.area.width * context.widthRatio)))
        }.sorted { $0.saved.frame.minX < $1.saved.frame.minX }
    }

    private func isCurrent(_ strip: Strip) -> Bool {
        SpaceManagementService.userDesktop(onDisplay: strip.display.uuid) == strip.space
    }

    private func revealSelected(_ strip: Strip) {
        guard let index = strip.entries.firstIndex(where: { $0.saved.id == strip.selected }) else { return }
        strip.offset = CanvasLayout.reveal(index, widths: strip.entries.map(\.width), viewport: strip.display.area.width, offset: strip.offset)
    }

    private func render(_ strip: Strip, context: Context, focus: Bool) {
        guard isCurrent(strip) else { return }
        strip.offset = CanvasLayout.clampedOffset(strip.offset, widths: strip.entries.map(\.width), viewport: strip.display.area.width)
        let frames = CanvasLayout.placements(widths: strip.entries.map(\.width), area: strip.display.area,
            offset: strip.offset, otherDisplays: context.displays.filter { $0.id != strip.display.id }.map(\.bounds))
        for (entry, placement) in zip(strip.entries, frames) {
            guard CanvasWindowAccess.id(entry.window) == entry.saved.id,
                  CanvasWindowAccess.eligible(entry.window),
                  SpaceManagementService.desktops(forWindow: entry.saved.id) == [strip.space] else { continue }
            _ = CanvasWindowAccess.setFrame(placement.frame, window: entry.window)
            // Respect applications' minimum widths on subsequent layouts.
            if let actual = CanvasWindowAccess.frame(entry.window), actual.width > entry.width + 2 {
                entry.width = actual.width
            }
        }
        // Parked windows remain behind the visible strip, especially at seams.
        for (entry, placement) in zip(strip.entries, frames) where !placement.parked {
            AXUIElementPerformAction(entry.window, kAXRaiseAction as CFString)
        }
        if let entry = strip.entries.first(where: { $0.saved.id == strip.selected }), CanvasWindowAccess.eligible(entry.window) {
            AXUIElementPerformAction(entry.window, kAXRaiseAction as CFString)
            if focus { CanvasWindowAccess.focus(entry.window, pid: entry.saved.pid) }
        }
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
                    let dead = context.apps[entry.saved.pid] != entry.saved.launchedAt || CanvasWindowAccess.id(entry.window) != entry.saved.id
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
                if !additions.isEmpty { strip.entries.append(contentsOf: additions); changed = true }
                if let focused, focused != strip.selected, strip.entries.contains(where: { $0.saved.id == focused }) {
                    strip.selected = focused
                    self.revealSelected(strip)
                    changed = true
                }
                if strip.entries.isEmpty { self.strips.removeValue(forKey: id); self.publish() }
                else if changed { self.render(strip, context: context, focus: false) }
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
            if !context.displays.contains(where: { $0.bounds.intersects(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 24)) }), let display = context.displays.first {
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
