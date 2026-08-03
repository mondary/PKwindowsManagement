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
    case topFirstSixth
    case topCenterSixth
    case topLastSixth
    case bottomFirstSixth
    case bottomCenterSixth
    case bottomLastSixth
    case fullScreen
    case nextDisplay
    case previousDisplay
}

struct WindowMargins: Codable, Equatable {
    var top: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat

    init(top: CGFloat = 0, bottom: CGFloat = 0, left: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }

    static let zero = WindowMargins()
}

struct WindowMarginPreset {
    var general: WindowMargins
    var almostFull: WindowMargins
    var center: WindowMargins

    init(general: WindowMargins = .zero, almostFull: WindowMargins = .zero, center: WindowMargins = .zero) {
        self.general = general
        self.almostFull = almostFull
        self.center = center
    }
}

private enum WindowCycleFamily {
    case left
    case right
}

final class WindowSnapService {
    func perform(_ action: WindowSnapAction, preset: WindowMarginPreset = WindowMarginPreset()) {
        guard ensureAccessibilityPermission() else { return }
        guard let focusedWindow = focusedAXWindow(),
              let currentFrame = frame(of: focusedWindow)
        else { return }

        let targetScreen = screen(for: currentFrame) ?? NSScreen.main
        guard let targetScreen else { return }

        // AX window coordinates use a top-left origin, NSScreen.visibleFrame uses
        // a bottom-left origin: flip the vertical axis before building frames.
        let mainHeight = primaryScreenHeight
        let visible = targetScreen.visibleFrame
        let axTop = mainHeight - visible.maxY
        let visibleAX = CGRect(x: visible.minX, y: axTop, width: visible.width, height: visible.height)
        let baseAX = insetFrame(visibleAX, by: preset.general)

        let targetFrame: CGRect

        switch action {
        case .leftHalf:
            targetFrame = cycleFrame(current: currentFrame, visible: baseAX, family: .left)
        case .rightHalf:
            targetFrame = cycleFrame(current: currentFrame, visible: baseAX, family: .right)
        case .topHalf:
            let halfHeight = floor(baseAX.height / 2.0)
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.minY, width: baseAX.width, height: halfHeight)
        case .bottomHalf:
            let halfHeight = floor(baseAX.height / 2.0)
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.maxY - halfHeight, width: baseAX.width, height: halfHeight)
        case .maximize:
            targetFrame = insetFrame(baseAX, by: preset.almostFull)
        case .fullScreen:
            targetFrame = CGRect(x: targetScreen.frame.minX, y: mainHeight - targetScreen.frame.maxY, width: targetScreen.frame.width, height: targetScreen.frame.height)
        case .center:
            let area = insetFrame(baseAX, by: preset.center)
            let width = min(currentFrame.width, area.width)
            let height = min(currentFrame.height, area.height)
            let x = area.minX + (area.width - width) / 2.0
            let y = area.minY + (area.height - height) / 2.0
            targetFrame = CGRect(x: round(x), y: round(y), width: round(width), height: round(height))
        case .topLeft:
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.minY, width: floor(baseAX.width / 2.0), height: floor(baseAX.height / 2.0))
        case .topRight:
            targetFrame = CGRect(x: baseAX.midX, y: baseAX.minY, width: floor(baseAX.width / 2.0), height: floor(baseAX.height / 2.0))
        case .bottomLeft:
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.midY, width: floor(baseAX.width / 2.0), height: floor(baseAX.height / 2.0))
        case .bottomRight:
            targetFrame = CGRect(x: baseAX.midX, y: baseAX.midY, width: floor(baseAX.width / 2.0), height: floor(baseAX.height / 2.0))
        case .firstThird:
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.minY, width: floor(baseAX.width / 3.0), height: baseAX.height)
        case .centerThird:
            let w = floor(baseAX.width / 3.0)
            targetFrame = CGRect(x: baseAX.minX + w, y: baseAX.minY, width: w, height: baseAX.height)
        case .lastThird:
            let w = floor(baseAX.width / 3.0)
            targetFrame = CGRect(x: baseAX.maxX - w, y: baseAX.minY, width: w, height: baseAX.height)
        case .topFirstSixth:
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.minY, width: floor(baseAX.width / 3.0), height: floor(baseAX.height / 2.0))
        case .topCenterSixth:
            let w = floor(baseAX.width / 3.0)
            targetFrame = CGRect(x: baseAX.minX + w, y: baseAX.minY, width: w, height: floor(baseAX.height / 2.0))
        case .topLastSixth:
            let w = floor(baseAX.width / 3.0)
            targetFrame = CGRect(x: baseAX.maxX - w, y: baseAX.minY, width: w, height: floor(baseAX.height / 2.0))
        case .bottomFirstSixth:
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.midY, width: floor(baseAX.width / 3.0), height: floor(baseAX.height / 2.0))
        case .bottomCenterSixth:
            let w = floor(baseAX.width / 3.0)
            targetFrame = CGRect(x: baseAX.minX + w, y: baseAX.midY, width: w, height: floor(baseAX.height / 2.0))
        case .bottomLastSixth:
            let w = floor(baseAX.width / 3.0)
            targetFrame = CGRect(x: baseAX.maxX - w, y: baseAX.midY, width: w, height: floor(baseAX.height / 2.0))
        case .nextDisplay, .previousDisplay:
            guard let moved = moveToAnotherDisplay(
                currentFrame: currentFrame,
                currentScreen: targetScreen,
                direction: action == .nextDisplay ? 1 : -1,
                mainHeight: mainHeight
            ) else { return }
            targetFrame = moved
        }

        setFrame(targetFrame, for: focusedWindow)
    }

    private func insetFrame(_ rect: CGRect, by margins: WindowMargins) -> CGRect {
        let dx = rect.width * margins.left / 100
        let dw = rect.width * margins.right / 100
        let dy = rect.height * margins.top / 100
        let dh = rect.height * margins.bottom / 100
        return CGRect(
            x: rect.minX + dx,
            y: rect.minY + dy,
            width: max(0, rect.width - dx - dw),
            height: max(0, rect.height - dy - dh)
        )
    }

    private static var cycleIndex: [String: Int] = [:]
    private static var cycleTime: [String: Date] = [:]

    private func cycleFrame(current: CGRect, visible: CGRect, family: WindowCycleFamily) -> CGRect {
        let halfWidth = floor(visible.width / 2.0)
        let thirdWidth = floor(visible.width / 3.0)
        let twoThirdsWidth = floor(visible.width * 2.0 / 3.0)

        let candidates: [CGRect]
        switch family {
        case .left:
            candidates = [
                CGRect(x: visible.minX, y: visible.minY, width: halfWidth, height: visible.height),
                CGRect(x: visible.minX, y: visible.minY, width: twoThirdsWidth, height: visible.height),
                CGRect(x: visible.minX, y: visible.minY, width: thirdWidth, height: visible.height)
            ]
        case .right:
            candidates = [
                CGRect(x: visible.maxX - halfWidth, y: visible.minY, width: halfWidth, height: visible.height),
                CGRect(x: visible.maxX - twoThirdsWidth, y: visible.minY, width: twoThirdsWidth, height: visible.height),
                CGRect(x: visible.maxX - thirdWidth, y: visible.minY, width: thirdWidth, height: visible.height)
            ]
        }

        let key = family == .left ? "left" : "right"
        let now = Date()
        let lastTime = Self.cycleTime[key] ?? .distantPast
        let withinWindow = now.timeIntervalSince(lastTime) <= 3.0

        let nextIndex: Int
        if withinWindow {
            let stored = Self.cycleIndex[key] ?? 0
            nextIndex = (stored + 1) % candidates.count
        } else if let matched = candidates.firstIndex(where: { cycleMatches($0, current, reference: visible.width) }) {
            nextIndex = (matched + 1) % candidates.count
        } else {
            nextIndex = 0
        }

        Self.cycleIndex[key] = nextIndex
        Self.cycleTime[key] = now
        return candidates[nextIndex]
    }

    private func cycleMatches(_ candidate: CGRect, _ current: CGRect, reference: CGFloat) -> Bool {
        let tolerance = max(20, reference * 0.10)
        let widthMatch = abs(candidate.width - current.width) <= tolerance
        let xMatch = abs(candidate.minX - current.minX) <= tolerance
        let heightMatch = abs(candidate.height - current.height) <= tolerance
        let yMatch = abs(candidate.minY - current.minY) <= tolerance
        return widthMatch && xMatch && heightMatch && yMatch
    }

    private func framesMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 1 && abs(lhs.minY - rhs.minY) <= 1 &&
            abs(lhs.width - rhs.width) <= 1 && abs(lhs.height - rhs.height) <= 1
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

        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
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

    private func moveToAnotherDisplay(currentFrame: CGRect, currentScreen: NSScreen, direction: Int, mainHeight: CGFloat) -> CGRect? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }
        guard let currentIndex = screens.firstIndex(where: { $0 === currentScreen }) else { return nil }
        let nextIndex = (currentIndex + direction + screens.count) % screens.count
        let nextVisible = screens[nextIndex].visibleFrame
        let currentVisible = currentScreen.visibleFrame
        let currentAXTop = mainHeight - currentVisible.maxY
        let nextAXTop = mainHeight - nextVisible.maxY

        let widthRatio = currentVisible.width > 0 ? currentFrame.width / currentVisible.width : 0.6
        let heightRatio = currentVisible.height > 0 ? currentFrame.height / currentVisible.height : 0.8
        let xRatio = currentVisible.width > 0 ? (currentFrame.minX - currentVisible.minX) / currentVisible.width : 0.2
        let yRatio = currentVisible.height > 0 ? (currentFrame.minY - currentAXTop) / currentVisible.height : 0.2

        let width = min(nextVisible.width, max(280, round(nextVisible.width * widthRatio)))
        let height = min(nextVisible.height, max(220, round(nextVisible.height * heightRatio)))
        let x = nextVisible.minX + round((nextVisible.width - width) * xRatio)
        let y = nextAXTop + round((nextVisible.height - height) * yRatio)

        return CGRect(
            x: min(max(x, nextVisible.minX), nextVisible.maxX - width),
            y: min(max(y, nextAXTop), nextAXTop + nextVisible.height - height),
            width: width,
            height: height
        )
    }
}

extension ShortcutAction {
    var windowSnapAction: WindowSnapAction? {
        switch self {
        case .windowLeftHalf: .leftHalf
        case .windowRightHalf: .rightHalf
        case .windowTopHalf: .topHalf
        case .windowBottomHalf: .bottomHalf
        case .windowMaximize: .maximize
        case .windowCenter: .center
        case .windowTopLeft: .topLeft
        case .windowTopRight: .topRight
        case .windowBottomLeft: .bottomLeft
        case .windowBottomRight: .bottomRight
        case .windowFirstThird: .firstThird
        case .windowCenterThird: .centerThird
        case .windowLastThird: .lastThird
        case .windowTopFirstSixth: .topFirstSixth
        case .windowTopCenterSixth: .topCenterSixth
        case .windowTopLastSixth: .topLastSixth
        case .windowBottomFirstSixth: .bottomFirstSixth
        case .windowBottomCenterSixth: .bottomCenterSixth
        case .windowBottomLastSixth: .bottomLastSixth
        case .windowFullScreen: .fullScreen
        case .windowNextDisplay: .nextDisplay
        case .windowPreviousDisplay: .previousDisplay
        }
    }
}
