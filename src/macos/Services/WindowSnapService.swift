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
    case toggleFullscreen
    case nextDisplay
    case previousDisplay
    case maximizeHeight
    case maximizeWidth
    case makeLarger
    case makeSmaller
    case reasonableSize
    case restore
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case topThird
    case bottomThird
    case topTwoThirds
    case bottomTwoThirds
    case firstTwoThirds
    case centerTwoThirds
    case lastTwoThirds
    case firstFourth
    case secondFourth
    case thirdFourth
    case lastFourth
    case firstThreeFourths
    case centerThreeFourths
    case lastThreeFourths
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
        guard let (focusedWindow, appElement) = focusedAXWindow(),
              let currentFrame = frame(of: focusedWindow)
        else { return }

        if action == .restore {
            if let restored = Self.restoreStore.removeValue(forKey: Self.windowKey(for: focusedWindow)) {
                setFrame(restored, for: focusedWindow, on: appElement)
            }
            return
        }
        if action == .toggleFullscreen {
            toggleFullScreen(for: focusedWindow)
            return
        }

        Self.restoreStore[Self.windowKey(for: focusedWindow)] = currentFrame

        let targetScreen = screen(for: currentFrame) ?? NSScreen.main
        guard let targetScreen else { return }

        // AX window coordinates use a top-left origin, NSScreen.visibleFrame uses
        // a bottom-left origin: flip the vertical axis before building frames.
        let mainHeight = primaryScreenHeight
        let visible = targetScreen.visibleFrame
        let axTop = mainHeight - visible.maxY
        let visibleAX = CGRect(x: visible.minX, y: axTop, width: visible.width, height: visible.height)
        // General margins are applied per snap region (creates a gap between
        // adjacent halves/thirds/quarters), not just around the working area.
        let baseAX = visibleAX

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
        case .maximizeHeight:
            let width = min(currentFrame.width, baseAX.width)
            let x = max(baseAX.minX, min(currentFrame.minX, baseAX.maxX - width))
            targetFrame = CGRect(x: x, y: baseAX.minY, width: width, height: baseAX.height)
        case .maximizeWidth:
            let height = min(currentFrame.height, baseAX.height)
            let y = max(baseAX.minY, min(currentFrame.minY, baseAX.maxY - height))
            targetFrame = CGRect(x: baseAX.minX, y: y, width: baseAX.width, height: height)
        case .makeLarger:
            let width = min(baseAX.width, currentFrame.width * 1.05)
            let height = min(baseAX.height, currentFrame.height * 1.05)
            targetFrame = centered(currentFrame, to: width, height: height, in: baseAX)
        case .makeSmaller:
            let width = max(100, currentFrame.width * 0.95)
            let height = max(60, currentFrame.height * 0.95)
            targetFrame = centered(currentFrame, to: width, height: height, in: baseAX)
        case .reasonableSize:
            let width = floor(baseAX.width * 0.6)
            let height = floor(baseAX.height * 0.6)
            let x = baseAX.minX + floor((baseAX.width - width) / 2.0)
            let y = baseAX.minY + floor((baseAX.height - height) / 2.0)
            targetFrame = CGRect(x: x, y: y, width: width, height: height)
        case .moveLeft:
            let step = floor(baseAX.width * 0.05)
            targetFrame = translated(currentFrame, in: baseAX, x: currentFrame.minX - step, y: currentFrame.minY)
        case .moveRight:
            let step = floor(baseAX.width * 0.05)
            targetFrame = translated(currentFrame, in: baseAX, x: currentFrame.minX + step, y: currentFrame.minY)
        case .moveUp:
            let step = floor(baseAX.height * 0.05)
            targetFrame = translated(currentFrame, in: baseAX, x: currentFrame.minX, y: currentFrame.minY - step)
        case .moveDown:
            let step = floor(baseAX.height * 0.05)
            targetFrame = translated(currentFrame, in: baseAX, x: currentFrame.minX, y: currentFrame.minY + step)
        case .topThird:
            let h = floor(baseAX.height / 3.0)
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.minY, width: baseAX.width, height: h)
        case .bottomThird:
            let h = floor(baseAX.height / 3.0)
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.maxY - h, width: baseAX.width, height: h)
        case .topTwoThirds:
            let h = floor(baseAX.height * 2.0 / 3.0)
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.minY, width: baseAX.width, height: h)
        case .bottomTwoThirds:
            let h = floor(baseAX.height * 2.0 / 3.0)
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.maxY - h, width: baseAX.width, height: h)
        case .firstTwoThirds:
            let w = floor(baseAX.width * 2.0 / 3.0)
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.minY, width: w, height: baseAX.height)
        case .centerTwoThirds:
            let w = floor(baseAX.width * 2.0 / 3.0)
            targetFrame = CGRect(x: baseAX.minX + floor((baseAX.width - w) / 2.0), y: baseAX.minY, width: w, height: baseAX.height)
        case .lastTwoThirds:
            let w = floor(baseAX.width * 2.0 / 3.0)
            targetFrame = CGRect(x: baseAX.maxX - w, y: baseAX.minY, width: w, height: baseAX.height)
        case .firstFourth:
            let w = floor(baseAX.width / 4.0)
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.minY, width: w, height: baseAX.height)
        case .secondFourth:
            let w = floor(baseAX.width / 4.0)
            targetFrame = CGRect(x: baseAX.minX + w, y: baseAX.minY, width: w, height: baseAX.height)
        case .thirdFourth:
            let w = floor(baseAX.width / 4.0)
            targetFrame = CGRect(x: baseAX.minX + 2 * w, y: baseAX.minY, width: w, height: baseAX.height)
        case .lastFourth:
            let w = floor(baseAX.width / 4.0)
            targetFrame = CGRect(x: baseAX.maxX - w, y: baseAX.minY, width: w, height: baseAX.height)
        case .firstThreeFourths:
            let w = floor(baseAX.width * 3.0 / 4.0)
            targetFrame = CGRect(x: baseAX.minX, y: baseAX.minY, width: w, height: baseAX.height)
        case .centerThreeFourths:
            let w = floor(baseAX.width * 3.0 / 4.0)
            targetFrame = CGRect(x: baseAX.minX + floor((baseAX.width - w) / 2.0), y: baseAX.minY, width: w, height: baseAX.height)
        case .lastThreeFourths:
            let w = floor(baseAX.width * 3.0 / 4.0)
            targetFrame = CGRect(x: baseAX.maxX - w, y: baseAX.minY, width: w, height: baseAX.height)
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
        case .restore, .toggleFullscreen:
            targetFrame = currentFrame
        case .nextDisplay, .previousDisplay:
            guard let moved = moveToAnotherDisplay(
                currentFrame: currentFrame,
                currentScreen: targetScreen,
                direction: action == .nextDisplay ? 1 : -1,
                mainHeight: mainHeight
            ) else { return }
            targetFrame = moved
        }

        let finalFrame = Self.snapGapActions.contains(action)
            ? insetByGaps(targetFrame, area: visibleAX, by: preset.general)
            : targetFrame
        setFrame(finalFrame, for: focusedWindow, on: appElement)
    }

    private static let snapGapActions: Set<WindowSnapAction> = [
        .leftHalf, .rightHalf, .topHalf, .bottomHalf,
        .topLeft, .topRight, .bottomLeft, .bottomRight,
        .firstThird, .centerThird, .lastThird,
        .topFirstSixth, .topCenterSixth, .topLastSixth,
        .bottomFirstSixth, .bottomCenterSixth, .bottomLastSixth,
        .topThird, .bottomThird, .topTwoThirds, .bottomTwoThirds,
        .firstTwoThirds, .centerTwoThirds, .lastTwoThirds,
        .firstFourth, .secondFourth, .thirdFourth, .lastFourth,
        .firstThreeFourths, .centerThreeFourths, .lastThreeFourths,
        .maximizeHeight, .maximizeWidth
    ]

    private func insetByGaps(_ frame: CGRect, area: CGRect, by margins: WindowMargins) -> CGRect {
        let dx = area.width * margins.left / 100
        let dw = area.width * margins.right / 100
        let dy = area.height * margins.top / 100
        let dh = area.height * margins.bottom / 100
        // Un bord sur le bord de l'écran compte plein, un bord intérieur
        // (collé à une autre zone de snap) compte à moitié : le gap total
        // entre deux zones vaut une seule fois la marge.
        let epsilon: CGFloat = 0.5
        let leftGap = dx * (frame.minX > area.minX + epsilon ? 0.5 : 1.0)
        let rightGap = dw * (frame.maxX < area.maxX - epsilon ? 0.5 : 1.0)
        let topGap = dy * (frame.minY > area.minY + epsilon ? 0.5 : 1.0)
        let bottomGap = dh * (frame.maxY < area.maxY - epsilon ? 0.5 : 1.0)
        return CGRect(
            x: frame.minX + leftGap,
            y: frame.minY + topGap,
            width: max(0, frame.width - leftGap - rightGap),
            height: max(0, frame.height - topGap - bottomGap)
        )
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

    private func focusedAXWindow() -> (AXUIElement, AXUIElement)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: AnyObject?
        let windowStatus = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)
        if windowStatus == .success, let windowElement = windowRef {
            return (windowElement as! AXUIElement, appElement)
        }

        var windowsRef: AnyObject?
        let windowsStatus = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        if windowsStatus == .success,
           let windows = windowsRef as? [AXUIElement],
           let firstWindow = windows.first
        {
            return (firstWindow, appElement)
        }
        return nil
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, on: window),
              let size = sizeAttribute(kAXSizeAttribute as CFString, on: window)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement, on appElement: AXUIElement) {
        let enhancedKey = "AXEnhancedUserInterface" as CFString
        var enhancedWasOn = false
        var prev: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, enhancedKey, &prev) == .success,
           let flag = prev as? Bool, flag
        {
            enhancedWasOn = true
            AXUIElementSetAttributeValue(appElement, enhancedKey, kCFBooleanFalse)
        }

        var sz = frame.size
        var pt = frame.origin
        guard let sizeValue1 = AXValueCreate(.cgSize, &sz),
              let pointValue = AXValueCreate(.cgPoint, &pt),
              let sizeValue2 = AXValueCreate(.cgSize, &sz)
        else { return }

        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue1)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue2)

        if enhancedWasOn {
            AXUIElementSetAttributeValue(appElement, enhancedKey, kCFBooleanTrue)
        }
    }

    private static var restoreStore: [CFHashCode: CGRect] = [:]

    private static func windowKey(for window: AXUIElement) -> CFHashCode {
        CFHash(window)
    }

    private func toggleFullScreen(for window: AXUIElement) {
        let attribute = "AXFullScreen" as CFString
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(window, attribute, &value)
        let isFull = status == .success ? (value as? Bool) ?? false : false
        AXUIElementSetAttributeValue(window, attribute, isFull ? kCFBooleanFalse : kCFBooleanTrue)
    }

    private func centered(_ frame: CGRect, to width: CGFloat, height: CGFloat, in bounds: CGRect) -> CGRect {
        CGRect(
            x: min(max(frame.midX - width / 2.0, bounds.minX), bounds.maxX - width),
            y: min(max(frame.midY - height / 2.0, bounds.minY), bounds.maxY - height),
            width: width,
            height: height
        )
    }

    private func translated(_ frame: CGRect, in bounds: CGRect, x: CGFloat, y: CGFloat) -> CGRect {
        let width = frame.width
        let height = frame.height
        return CGRect(
            x: max(bounds.minX, min(x, bounds.maxX - width)),
            y: max(bounds.minY, min(y, bounds.maxY - height)),
            width: width,
            height: height
        )
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
        case .windowToggleFullScreen: .toggleFullscreen
        case .windowNextDisplay: .nextDisplay
        case .windowPreviousDisplay: .previousDisplay
        case .windowMaximizeHeight: .maximizeHeight
        case .windowMaximizeWidth: .maximizeWidth
        case .windowMakeLarger: .makeLarger
        case .windowMakeSmaller: .makeSmaller
        case .windowReasonableSize: .reasonableSize
        case .windowRestore: .restore
        case .windowMoveLeft: .moveLeft
        case .windowMoveRight: .moveRight
        case .windowMoveUp: .moveUp
        case .windowMoveDown: .moveDown
        case .windowTopThird: .topThird
        case .windowBottomThird: .bottomThird
        case .windowTopTwoThirds: .topTwoThirds
        case .windowBottomTwoThirds: .bottomTwoThirds
        case .windowFirstTwoThirds: .firstTwoThirds
        case .windowCenterTwoThirds: .centerTwoThirds
        case .windowLastTwoThirds: .lastTwoThirds
        case .windowFirstFourth: .firstFourth
        case .windowSecondFourth: .secondFourth
        case .windowThirdFourth: .thirdFourth
        case .windowLastFourth: .lastFourth
        case .windowFirstThreeFourths: .firstThreeFourths
        case .windowCenterThreeFourths: .centerThreeFourths
        case .windowLastThreeFourths: .lastThreeFourths
        }
    }
}
