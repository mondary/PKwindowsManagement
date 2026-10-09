import AppKit
import ApplicationServices
import Darwin

enum CanvasWindowAccess {
    static func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
        return result
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
        var id: CGWindowID = 0
        guard let getWindow, getWindow(window, &id) == .success, id != 0 else { return nil }
        return id
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
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s)
        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, p)
        return sizeResult == .success && positionResult == .success
    }

    static func windows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        return value(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
    }

    static func eligible(_ window: AXUIElement) -> Bool {
        guard value(window, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole,
              value(window, kAXMinimizedAttribute) as? Bool != true,
              value(window, "AXFullScreen") as? Bool != true else { return false }
        if let sheets = value(window, "AXSheets") as? [AXUIElement], !sheets.isEmpty { return false }
        var movable = DarwinBoolean(false)
        var resizable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &movable) == .success
            && AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &resizable) == .success
            && movable.boolValue && resizable.boolValue
    }

    static func focusedID(pid: pid_t?) -> CGWindowID? {
        guard let pid else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        return element(value(app, kAXFocusedWindowAttribute)).flatMap { id($0) }
    }

    static func focus(_ window: AXUIElement, pid: pid_t) {
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        DispatchQueue.main.sync {
            _ = NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateIgnoringOtherApps])
        }
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, window)
    }
}
