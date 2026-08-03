import AppKit

final class SimpleWindowManager {
    func moveWindowLeft() {
        guard ensureAccessibilityPermission() else { return }
        guard let focusedWindow = focusedAXWindow(),
              let currentFrame = frame(of: focusedWindow)
        else { return }

        let screen = screen(for: currentFrame) ?? NSScreen.main
        guard let screen else { return }

        let visible = screen.visibleFrame
        let halfWidth = floor(visible.width / 2.0)

        let targetFrame = CGRect(x: visible.minX, y: visible.minY, width: halfWidth, height: visible.height)
        setFrame(targetFrame, for: focusedWindow)
    }

    func moveWindowRight() {
        guard ensureAccessibilityPermission() else { return }
        guard let focusedWindow = focusedAXWindow(),
              let currentFrame = frame(of: focusedWindow)
        else { return }

        let screen = screen(for: currentFrame) ?? NSScreen.main
        guard let screen else { return }

        let visible = screen.visibleFrame
        let halfWidth = floor(visible.width / 2.0)

        let targetFrame = CGRect(x: visible.maxX - halfWidth, y: visible.minY, width: halfWidth, height: visible.height)
        setFrame(targetFrame, for: focusedWindow)
    }

    func maximizeWindow() {
        guard ensureAccessibilityPermission() else { return }
        guard let focusedWindow = focusedAXWindow(),
              let currentFrame = frame(of: focusedWindow)
        else { return }

        let screen = screen(for: currentFrame) ?? NSScreen.main
        guard let screen else { return }

        let targetFrame = screen.visibleFrame
        setFrame(targetFrame, for: focusedWindow)
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    private func focusedAXWindow() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var appRef: AnyObject?
        let appStatus = AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &appRef)
        guard appStatus == .success, let appElement = appRef else { return nil }

        var windowRef: AnyObject?
        let windowStatus = AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard windowStatus == .success, let windowElement = windowRef else { return nil }
        return (windowElement as! AXUIElement)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, on: window),
              let size = sizeAttribute(kAXSizeAttribute as CFString, on: window)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement) {
        var point = frame.origin
        var size = frame.size

        guard let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return }

        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
    }

    private func pointAttribute(_ attribute: CFString, on element: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID()
        else { return nil }

        var point = CGPoint.zero
        let converted = AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return converted ? point : nil
    }

    private func sizeAttribute(_ attribute: CFString, on element: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID()
        else { return nil }

        var size = CGSize.zero
        let converted = AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return converted ? size : nil
    }

    private func screen(for frame: CGRect) -> NSScreen? {
        let mainHeight = primaryScreenHeight
        let nsCenter = CGPoint(x: frame.midX, y: mainHeight - frame.midY)
        if let byCenter = NSScreen.screens.first(where: { $0.frame.contains(nsCenter) }) {
            return byCenter
        }
        let nsFrame = CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height)
        return NSScreen.screens.max(by: { lhs, rhs in
            intersectionArea(lhs.frame, nsFrame) < intersectionArea(rhs.frame, nsFrame)
        })
    }

    private var primaryScreenHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? 0
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}