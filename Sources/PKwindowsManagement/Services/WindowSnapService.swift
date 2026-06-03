import AppKit
import ApplicationServices

enum WindowSnapAction: CaseIterable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case maximize
    case center
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case firstThird
    case centerThird
    case lastThird
    case nextDisplay
    case previousDisplay
}

final class WindowSnapService {
    func perform(_ action: WindowSnapAction) {
        guard ensureAccessibilityPermission() else { return }
        guard let focusedWindow = focusedAXWindow(),
              let currentFrame = frame(of: focusedWindow)
        else { return }

        let targetScreen = screen(for: currentFrame) ?? NSScreen.main
        guard let targetScreen else { return }

        let visible = targetScreen.visibleFrame
        let targetFrame: CGRect

        switch action {
        case .leftHalf:
            targetFrame = CGRect(x: visible.minX, y: visible.minY, width: floor(visible.width / 2.0), height: visible.height)
        case .rightHalf:
            let halfWidth = floor(visible.width / 2.0)
            targetFrame = CGRect(x: visible.maxX - halfWidth, y: visible.minY, width: halfWidth, height: visible.height)
        case .topHalf:
            let halfHeight = floor(visible.height / 2.0)
            targetFrame = CGRect(x: visible.minX, y: visible.maxY - halfHeight, width: visible.width, height: halfHeight)
        case .bottomHalf:
            let halfHeight = floor(visible.height / 2.0)
            targetFrame = CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: halfHeight)
        case .maximize:
            targetFrame = visible
        case .center:
            let width = min(currentFrame.width, visible.width)
            let height = min(currentFrame.height, visible.height)
            let x = visible.minX + (visible.width - width) / 2.0
            let y = visible.minY + (visible.height - height) / 2.0
            targetFrame = CGRect(x: round(x), y: round(y), width: round(width), height: round(height))
        case .topLeft:
            targetFrame = CGRect(x: visible.minX, y: visible.midY, width: floor(visible.width / 2.0), height: floor(visible.height / 2.0))
        case .topRight:
            targetFrame = CGRect(x: visible.midX, y: visible.midY, width: floor(visible.width / 2.0), height: floor(visible.height / 2.0))
        case .bottomLeft:
            targetFrame = CGRect(x: visible.minX, y: visible.minY, width: floor(visible.width / 2.0), height: floor(visible.height / 2.0))
        case .bottomRight:
            targetFrame = CGRect(x: visible.midX, y: visible.minY, width: floor(visible.width / 2.0), height: floor(visible.height / 2.0))
        case .firstThird:
            targetFrame = CGRect(x: visible.minX, y: visible.minY, width: floor(visible.width / 3.0), height: visible.height)
        case .centerThird:
            let w = floor(visible.width / 3.0)
            targetFrame = CGRect(x: visible.minX + w, y: visible.minY, width: w, height: visible.height)
        case .lastThird:
            let w = floor(visible.width / 3.0)
            targetFrame = CGRect(x: visible.maxX - w, y: visible.minY, width: w, height: visible.height)
        case .nextDisplay, .previousDisplay:
            guard let moved = moveToAnotherDisplay(
                currentFrame: currentFrame,
                currentScreen: targetScreen,
                direction: action == .nextDisplay ? 1 : -1
            ) else { return }
            targetFrame = moved
        }

        setFrame(targetFrame, for: focusedWindow)
    }

    func snapToColumns(total: Int, index: Int) {
        guard total >= 1, index >= 0, index < total else { return }
        guard ensureAccessibilityPermission() else { return }
        guard let focusedWindow = focusedAXWindow(),
              let currentFrame = frame(of: focusedWindow)
        else { return }
        guard let targetScreen = screen(for: currentFrame) ?? NSScreen.main else { return }

        let visible = targetScreen.visibleFrame
        let segmentWidth = floor(visible.width / CGFloat(total))
        let x = visible.minX + segmentWidth * CGFloat(index)
        let width: CGFloat = (index == total - 1) ? (visible.maxX - x) : segmentWidth
        let target = CGRect(x: x, y: visible.minY, width: width, height: visible.height)
        setFrame(target, for: focusedWindow)
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
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement) {
        var point = frame.origin
        var size = frame.size

        guard let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return }

        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }

    private func pointAttribute(_ attribute: CFString, on element: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID()
        else {
            return nil
        }

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
        else {
            return nil
        }

        var size = CGSize.zero
        let converted = AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return converted ? size : nil
    }

    private func screen(for frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let byCenter = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return byCenter
        }
        return NSScreen.screens.max(by: { lhs, rhs in
            intersectionArea(lhs.frame, frame) < intersectionArea(rhs.frame, frame)
        })
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }

    private func moveToAnotherDisplay(currentFrame: CGRect, currentScreen: NSScreen, direction: Int) -> CGRect? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }
        guard let currentIndex = screens.firstIndex(where: { $0 === currentScreen }) else { return nil }
        let nextIndex = (currentIndex + direction + screens.count) % screens.count
        let nextVisible = screens[nextIndex].visibleFrame
        let currentVisible = currentScreen.visibleFrame

        let widthRatio = currentVisible.width > 0 ? currentFrame.width / currentVisible.width : 0.6
        let heightRatio = currentVisible.height > 0 ? currentFrame.height / currentVisible.height : 0.8
        let xRatio = currentVisible.width > 0 ? (currentFrame.minX - currentVisible.minX) / currentVisible.width : 0.2
        let yRatio = currentVisible.height > 0 ? (currentFrame.minY - currentVisible.minY) / currentVisible.height : 0.2

        let width = min(nextVisible.width, max(280, round(nextVisible.width * widthRatio)))
        let height = min(nextVisible.height, max(220, round(nextVisible.height * heightRatio)))
        let x = nextVisible.minX + round((nextVisible.width - width) * xRatio)
        let y = nextVisible.minY + round((nextVisible.height - height) * yRatio)

        return CGRect(
            x: min(max(x, nextVisible.minX), nextVisible.maxX - width),
            y: min(max(y, nextVisible.minY), nextVisible.maxY - height),
            width: width,
            height: height
        )
    }
}
