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
            let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool == true
            if isOnScreen { onScreen.insert(id) }
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            if info[kCGWindowLayer as String] as? Int == 0,
               alpha > 0.01,
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
            let realWindows = expected[app.pid] ?? []
            let windows = CanvasWindowAccess.windows(pid: app.pid, expectedWindowIDs: realWindows, reconcile: true)
            for window in windows {
                if Task.isCancelled { break }
                guard CanvasWindowAccess.value(window, kAXRoleAttribute) as? String == kAXWindowRole,
                      let id = CanvasWindowAccess.id(window) else { continue }
                // Source de vérité : la liste CG (layer 0, taille plausible).
                // Les apps de barre de menus (accessory : MonitorControl,
                // Powerlines, Whisper…) exposent des fenêtres AX fantômes qui
                // produisaient des entrées Cmd+Tab sans fenêtre réelle.
                guard realWindows.contains(id) else { continue }
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

    /// Close the represented window, never the app or its currently focused window.
    /// Worker only: AX can wait for an unresponsive app or a save dialog.
    static func close(_ candidate: Candidate) -> WindowCloseRequest.Result {
        let id = candidate.item.id
        var button: AXUIElement?
        return WindowCloseRequest.run(isCancelled: { Task.isCancelled }, validate: {
            guard let app = NSRunningApplication(processIdentifier: id.pid), !app.isTerminated,
                  app.launchDate == candidate.launchedAt,
                  CanvasWindowAccess.id(candidate.element) == id.windowID,
                  CanvasWindowAccess.value(candidate.element, kAXRoleAttribute) as? String == kAXWindowRole
            else { return false }
            var owner: pid_t = 0
            guard AXUIElementGetPid(candidate.element, &owner) == .success, owner == id.pid,
                  let closeButton = CanvasWindowAccess.element(
                    CanvasWindowAccess.value(candidate.element, kAXCloseButtonAttribute))
            else { return false }
            AXUIElementSetMessagingTimeout(closeButton, 0.15)
            guard CanvasWindowAccess.value(closeButton, kAXEnabledAttribute) as? Bool == true else { return false }
            button = closeButton
            return true
        }, press: {
            guard let button else { return false }
            let result = CanvasWindowAccess.onAccessibilityThread(button) {
                AXUIElementPerformAction(button, kAXPressAction as CFString)
            }
            // cannotComplete can mean the app is waiting for a modal response.
            // Never retry the press, nor send Return to a possible save dialog.
            return result == .success || result == .cannotComplete
        }, isClosed: {
            if let app = NSRunningApplication(processIdentifier: id.pid) {
                if app.isTerminated || app.launchDate != candidate.launchedAt { return true }
            } else { return true }
            var role: CFTypeRef?
            let result = CanvasWindowAccess.onAccessibilityThread(candidate.element) {
                AXUIElementCopyAttributeValue(candidate.element, kAXRoleAttribute as CFString, &role)
            }
            // A failed/partial inventory is not evidence that the window closed.
            return result == .invalidUIElement
        }, pause: { Thread.sleep(forTimeInterval: 0.05) })
    }

    /// Ask the app that owns the selected window to quit. Graceful by design:
    /// the owning app keeps control of its save dialogs and unsaved documents.
    /// Worker only: launching a quit request and observing it can wait.
    static func quit(pid: pid_t, launchedAt: Date?, force: Bool = false) -> WindowQuitRequest.Result {
        WindowQuitRequest.run(isCancelled: { Task.isCancelled }, validate: {
            guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated,
                  app.launchDate == launchedAt else { return false }
            return true
        }, terminate: {
            guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return false }
            return force ? app.forceTerminate() : app.terminate()
        }, isTerminated: {
            NSRunningApplication(processIdentifier: pid)?.isTerminated ?? true
        }, pause: { Thread.sleep(forTimeInterval: 0.05) })
    }

    /// Quit an app that NSWorkspace reports without a usable pid (Steam:
    /// pid -1 behind a Steam.AppBundle launcher). Same graceful semantics as
    /// the pid-based quit; the instance is resolved by bundle identifier.
    /// Worker only: observing the quit can wait.
    static func quitInstance(bundleIdentifier: String, launchedAt: Date?, force: Bool = false) -> WindowQuitRequest.Result {
        func current() -> NSRunningApplication? {
            NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
            }
        }
        return WindowQuitRequest.run(isCancelled: { Task.isCancelled }, validate: {
            guard let app = current(), app.launchDate == launchedAt else { return false }
            return true
        }, terminate: {
            guard let app = current() else { return false }
            return force ? app.forceTerminate() : app.terminate()
        }, isTerminated: {
            current()?.isTerminated ?? true
        }, pause: { Thread.sleep(forTimeInterval: 0.05) })
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
