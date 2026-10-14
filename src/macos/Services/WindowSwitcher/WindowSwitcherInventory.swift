import AppKit
import ApplicationServices

/// Uses PK's existing AX reconciliation. No Switch source is included.
enum WindowSwitcherInventory {
    struct Application {
        let pid: pid_t
        let name: String
        let launchedAt: Date?
        let isHidden: Bool
    }

    struct Candidate {
        let item: WindowSwitcherItem
        let element: AXUIElement
        let launchedAt: Date?
    }

    struct Snapshot {
        let candidates: [Candidate]
        let focused: WindowSwitcherID?
    }

    /// Called on a worker: a stalled app must not block typing in the picker.
    static func collect(apps: [Application], frontmostPID: pid_t?) -> Snapshot {
        let infos = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var ranks: [CGWindowID: Int] = [:]
        var onScreen = Set<CGWindowID>()
        var expected: [pid_t: Set<CGWindowID>] = [:]
        for (rank, info) in infos.enumerated() {
            guard let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else { continue }
            ranks[id] = rank
            if info[kCGWindowIsOnscreen as String] as? Bool == true { onScreen.insert(id) }
            if info[kCGWindowLayer as String] as? Int == 0,
               let raw = info[kCGWindowBounds as String] as? [String: Any],
               let frame = CGRect(dictionaryRepresentation: raw as CFDictionary),
               frame.width > 80, frame.height > 60 {
                expected[pid, default: []].insert(id)
            }
        }
        let focused = frontmostPID.flatMap { pid in
            CanvasWindowAccess.focusedID(pid: pid).map { WindowSwitcherID(pid: pid, windowID: $0) }
        }
        var candidates: [Candidate] = []
        var seen = Set<WindowSwitcherID>()
        for app in apps {
            if Task.isCancelled { break }
            let windows = CanvasWindowAccess.windows(pid: app.pid, expectedWindowIDs: expected[app.pid] ?? [], reconcile: true)
            for window in windows {
                if Task.isCancelled { break }
                guard CanvasWindowAccess.value(window, kAXRoleAttribute) as? String == kAXWindowRole,
                      let id = CanvasWindowAccess.id(window) else { continue }
                let subrole = CanvasWindowAccess.value(window, kAXSubroleAttribute) as? String
                let document = subrole == kAXStandardWindowSubrole || subrole == nil || subrole == kAXUnknownSubrole
                    || (subrole == kAXDialogSubrole && CanvasWindowAccess.value(window, kAXMinimizeButtonAttribute) != nil)
                guard document else { continue }
                let identity = WindowSwitcherID(pid: app.pid, windowID: id)
                guard seen.insert(identity).inserted else { continue }
                candidates.append(Candidate(item: WindowSwitcherItem(
                    id: identity, appName: app.name,
                    title: CanvasWindowAccess.value(window, kAXTitleAttribute) as? String ?? "",
                    isMinimized: CanvasWindowAccess.value(window, kAXMinimizedAttribute) as? Bool == true,
                    isHidden: app.isHidden,
                    isFullScreen: CanvasWindowAccess.value(window, "AXFullScreen") as? Bool == true,
                    isOnScreen: onScreen.contains(id)
                ), element: window, launchedAt: app.launchedAt))
            }
        }
        candidates.sort { lhs, rhs in
            if lhs.item.id == rhs.item.id { return false }
            if lhs.item.id == focused { return true }
            if rhs.item.id == focused { return false }
            let a = ranks[lhs.item.id.windowID] ?? Int.max
            let b = ranks[rhs.item.id.windowID] ?? Int.max
            if a != b { return a < b }
            let name = lhs.item.appName.localizedStandardCompare(rhs.item.appName)
            if name != .orderedSame { return name == .orderedAscending }
            return lhs.item.id.windowID < rhs.item.id.windowID
        }
        return Snapshot(candidates: candidates, focused: focused)
    }

    /// Runs on a worker, after the picker has relinquished keyboard focus.
    static func activate(_ candidate: Candidate, selectionTicket: UInt64) -> Bool {
        func stillCurrent() -> Bool {
            SpaceManagementService.shared.windowSelectionTicket() == selectionTicket
        }
        let id = candidate.item.id
        guard stillCurrent(), let app = NSRunningApplication(processIdentifier: id.pid), !app.isTerminated,
              app.launchDate == candidate.launchedAt,
              CanvasWindowAccess.id(candidate.element) == id.windowID,
              CanvasWindowAccess.value(candidate.element, kAXRoleAttribute) as? String == kAXWindowRole
        else { return false }
        DispatchQueue.main.sync { if stillCurrent() { _ = app.unhide() } }
        guard stillCurrent() else { return false }
        if CanvasWindowAccess.value(candidate.element, kAXMinimizedAttribute) as? Bool == true {
            let result = CanvasWindowAccess.onAccessibilityThread(candidate.element) {
                AXUIElementSetAttributeValue(candidate.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            guard result == .success else { return false }
        }
        return CanvasWindowAccess.focus(candidate.element, pid: id.pid, stillCurrent: stillCurrent)
    }
}
