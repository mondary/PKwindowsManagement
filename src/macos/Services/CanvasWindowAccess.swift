import AppKit
import ApplicationServices
import Darwin

enum CanvasWindowAccess {
    /// AX calls targeting this process dispatch directly into AppKit, unlike
    /// cross-process AX messaging. Only those individual calls belong on main;
    /// the negotiation loop and its delays must stay on the Canvas worker.
    static func onAccessibilityThread<T>(_ element: AXUIElement, _ operation: () -> T) -> T {
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) == .success, pid == getpid(), !Thread.isMainThread {
            return DispatchQueue.main.sync(execute: operation)
        }
        return operation()
    }

    static func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        onAccessibilityThread(element) {
            var result: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
            return result
        }
    }

    @discardableResult
    private static func setValue(_ element: AXUIElement, _ key: CFString, _ value: CFTypeRef) -> AXError {
        onAccessibilityThread(element) { AXUIElementSetAttributeValue(element, key, value) }
    }

    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private static let getWindow: GetWindow? = {
        guard let handle = dlopen(nil, RTLD_NOW), let symbol = dlsym(handle, "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(symbol, to: GetWindow.self)
    }()

    static func id(_ window: AXUIElement) -> CGWindowID? {
        onAccessibilityThread(window) {
            var id: CGWindowID = 0
            guard let getWindow, getWindow(window, &id) == .success, id != 0 else { return nil }
            return id
        }
    }

    static func frame(_ window: AXUIElement) -> CGRect? {
        guard let p = value(window, kAXPositionAttribute), let s = value(window, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(p, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(s, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    static func setFrame(_ frame: CGRect, window: AXUIElement) -> Bool {
        var point = frame.origin
        var size = frame.size
        guard let p = AXValueCreate(.cgPoint, &point), let s = AXValueCreate(.cgSize, &size) else { return false }
        // Some apps constrain resizing using the old screen/position. Apply
        // position-size-position so the final titlebar alignment wins.
        setValue(window, kAXPositionAttribute as CFString, p)
        let sizeResult = setValue(window, kAXSizeAttribute as CFString, s)
        let positionResult = setValue(window, kAXPositionAttribute as CFString, p)
        return sizeResult == .success && positionResult == .success
    }

    /// Verified Canvas placement; scrolling remains position-only when size
    /// already matches. Called exclusively on the Canvas worker queue.
    static func applyCanvasFrame(_ frame: CGRect, window: AXUIElement,
                                 valid: () -> Bool) -> CanvasFrameApplication.Result {
        let original = self.frame(window)
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        let key = "AXEnhancedUserInterface" as CFString
        let resizing = original.map { !CanvasFrameApplication.fitsSize($0.size, frame.size) } ?? true
        let enhanced = resizing && value(app, "AXEnhancedUserInterface") as? Bool == true
        let disabled = enhanced && setValue(app, key, kCFBooleanFalse) == .success
        defer { if disabled { setValue(app, key, kCFBooleanTrue) } }
        return CanvasFrameApplication.apply(frame, initial: original,
            read: { self.frame(window) },
            size: { proposed in
                var size = proposed
                guard let value = AXValueCreate(.cgSize, &size) else { return false }
                return setValue(window, kAXSizeAttribute as CFString, value) == .success
            }, position: { proposed in
                var point = proposed
                guard let value = AXValueCreate(.cgPoint, &point) else { return false }
                return setValue(window, kAXPositionAttribute as CFString, value) == .success
            }, pause: { Thread.sleep(forTimeInterval: $0) }, valid: valid)
    }

    static func windows(pid: pid_t, expectedWindowIDs: Set<CGWindowID> = []) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        func readWindows() -> [AXUIElement] {
            var candidates = value(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
            // Electron can expose a window at the app root before AXWindows
            // catches up. Inspect direct children only, never the editor tree.
            candidates += (value(app, kAXChildrenAttribute) as? [AXUIElement] ?? []).filter {
                value($0, kAXRoleAttribute) as? String == kAXWindowRole
            }
            for key in [kAXMainWindowAttribute, kAXFocusedWindowAttribute] {
                if let window = element(value(app, key)) { candidates.append(window) }
            }
            return candidates
        }
        let windows = WindowInventoryReconciliation.collect(expected: expectedWindowIDs, read: readWindows,
            id: { id($0) }, same: { CFEqual($0, $1) }, initialize: {
            guard value(app, kAXHiddenAttribute) as? Bool != true else { return [] }
            // Also initialize PARTIAL inventories, not just an empty AXWindows.
            // Restore the previous flag and retain the initial results even if
            // the refreshed list is smaller or unavailable.
            let key = "AXManualAccessibility" as CFString
            let original = value(app, "AXManualAccessibility") as? Bool ?? false
            let changed = !original && setValue(app, key, kCFBooleanTrue) == .success
            defer { if changed { setValue(app, key, kCFBooleanFalse) } }
            return readWindows()
        })
        windows.forEach { AXUIElementSetMessagingTimeout($0, 0.15) }
        return windows
    }

    /// Document-sized WindowServer windows, including covered windows. This is
    /// an expectation for AX reconciliation, never permission to move a window.
    static func expectedWindowIDs(pid: pid_t) -> Set<CGWindowID> {
        let infos = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(infos.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let raw = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: raw as CFDictionary),
                  frame.width > 80, frame.height > 80 else { return nil }
            return (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        })
    }

    @discardableResult
    static func raise(_ window: AXUIElement) -> AXError {
        onAccessibilityThread(window) { AXUIElementPerformAction(window, kAXRaiseAction as CFString) }
    }

    static func eligible(_ window: AXUIElement) -> Bool {
        exclusionReason(window) == nil
    }

    static func exclusionReason(_ window: AXUIElement) -> String? {
        guard value(window, kAXRoleAttribute) as? String == kAXWindowRole else { return "Unsupported window type" }
        let subrole = value(window, kAXSubroleAttribute) as? String
        // Cross-platform document windows may omit the subrole or use AXUnknown.
        let documentDialog = subrole == kAXDialogSubrole && value(window, kAXMinimizeButtonAttribute) != nil
        guard subrole == nil || subrole == kAXStandardWindowSubrole || subrole == kAXUnknownSubrole || documentDialog else {
            return "Dialog or floating panel"
        }
        if value(window, kAXModalAttribute) as? Bool == true { return "Window with an open dialog" }
        if value(window, kAXMinimizedAttribute) as? Bool == true { return "Minimized window" }
        if value(window, "AXFullScreen") as? Bool == true { return "Full-screen window" }
        if let sheets = value(window, "AXSheets") as? [AXUIElement], !sheets.isEmpty { return "Window with an open dialog" }
        let settable = onAccessibilityThread(window) {
            var movable = DarwinBoolean(false)
            var resizable = DarwinBoolean(false)
            return AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &movable) == .success
                && AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &resizable) == .success
                && movable.boolValue && resizable.boolValue
        }
        return settable ? nil : "Position or size unavailable through Accessibility"
    }

    static func focusedID(pid: pid_t?) -> CGWindowID? {
        guard let pid else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        return element(value(app, kAXFocusedWindowAttribute)).flatMap { id($0) }
    }

    @discardableResult
    static func focus(_ window: AXUIElement, pid: pid_t, stillCurrent: () -> Bool = { true }) -> Bool {
        guard let targetID = id(window) else { return false }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        var focusedSince: TimeInterval?
        var didRaise = false
        while ProcessInfo.processInfo.systemUptime < deadline {
            guard stillCurrent(), id(window) == targetID else { return false }
            let frontmost = DispatchQueue.main.sync { NSWorkspace.shared.frontmostApplication?.processIdentifier }
            let focused = element(value(app, kAXFocusedWindowAttribute)).flatMap { id($0) }
            let now = ProcessInfo.processInfo.systemUptime
            if didRaise, frontmost == pid, focused == targetID {
                if focusedSince == nil { focusedSince = now }
                if now - (focusedSince ?? now) >= 0.15 { return true }
            } else {
                focusedSince = nil
                setValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                DispatchQueue.main.sync {
                    _ = NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateIgnoringOtherApps])
                }
                raise(window)
                setValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                setValue(app, kAXFocusedWindowAttribute as CFString, window)
                didRaise = true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }
}
