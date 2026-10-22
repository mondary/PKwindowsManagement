import AppKit
import ApplicationServices

enum WindowSnapAction: CaseIterable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case maximize
    case maximizeAll
    case maximizeAllInApp
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
    case tileAll
    case tileAllDesktops
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
        _ = Self.tilingCancellationObservers
        Self.tilingGeneration += 1
        // Space changes during a fullscreen exit must not cancel the deferred
        // maximize that follows it; only a new user command does.
        Self.snapGeneration += 1
        let generation = Self.snapGeneration

        if action == .maximizeAll || action == .maximizeAllInApp {
            let apps: [NSRunningApplication]
            if action == .maximizeAllInApp {
                apps = NSWorkspace.shared.frontmostApplication.map { [$0] } ?? []
            } else {
                apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
            }
            for app in apps {
                maximizeAllWindows(of: app, preset: preset, generation: generation)
            }
            return
        }

        if action == .tileAll || action == .tileAllDesktops {
            tileWindows(scope: action == .tileAll ? .currentDesktop : .allDesktops)
            return
        }

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
        // A native fullscreen window lives on its own Space and ignores frame
        // changes. Leave fullscreen first, then maximize once macOS has
        // returned the window to its desktop.
        if action == .maximize, isFullScreen(focusedWindow) {
            if leaveFullScreen(focusedWindow) {
                maximizeAfterLeavingFullScreen([focusedWindow], preset: preset, generation: generation)
            }
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
        case .restore, .toggleFullscreen, .maximizeAll, .maximizeAllInApp, .tileAll, .tileAllDesktops:
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

    /// Native fullscreen windows live on their own Space and ignore frame
    /// changes. Leaving fullscreen is an animated Space transition, so their
    /// almost-maximized frame is applied only once the window is back on its
    /// desktop and its frame has settled.
    private func maximizeAllWindows(of app: NSRunningApplication, preset: WindowMarginPreset, generation: Int) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.5)
        var windowsRef: AnyObject?
        let status = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        // Chromium hides windows that live on another Space (a fullscreen
        // Chrome window, typically). Reconcile against WindowServer so those
        // windows can still be taken out of fullscreen and maximized.
        var windows = status == .success ? ((windowsRef as? [AXUIElement]) ?? []) : []
        if windows.isEmpty {
            windows = CanvasWindowAccess.windows(
                pid: app.processIdentifier,
                expectedWindowIDs: CanvasWindowAccess.expectedWindowIDs(pid: app.processIdentifier),
                reconcile: true
            )
        }
        guard !windows.isEmpty else { return }

        var fullScreenWindows: [AXUIElement] = []
        for window in windows {
            AXUIElementSetMessagingTimeout(window, 1.0)
            if isMinimized(window) { continue }
            if isFullScreen(window) {
                if leaveFullScreen(window) { fullScreenWindows.append(window) }
                continue
            }
            maximize(window, on: appElement, preset: preset)
        }
        if !fullScreenWindows.isEmpty {
            maximizeAfterLeavingFullScreen(fullScreenWindows, preset: preset, generation: generation)
        }
    }

    private func maximize(_ window: AXUIElement, on appElement: AXUIElement, preset: WindowMarginPreset) {
        guard let windowFrame = frame(of: window),
              let targetFrame = maximizeTargetFrame(for: windowFrame, preset: preset)
        else { return }
        Self.restoreStore[Self.windowKey(for: window)] = windowFrame
        setFrame(targetFrame, for: window, on: appElement)
    }

    private func maximizeTargetFrame(for windowFrame: CGRect, preset: WindowMarginPreset) -> CGRect? {
        guard let targetScreen = screen(for: windowFrame) else { return nil }
        let mainHeight = primaryScreenHeight
        let visible = targetScreen.visibleFrame
        let visibleAX = CGRect(x: visible.minX, y: mainHeight - visible.maxY,
                               width: visible.width, height: visible.height)
        return insetFrame(visibleAX, by: preset.almostFull)
    }

    private static let fullScreenQueue = DispatchQueue(
        label: "design.mondary.windows.fullscreen", qos: .userInitiated)

    private func maximizeAfterLeavingFullScreen(_ windows: [AXUIElement],
                                                preset: WindowMarginPreset,
                                                generation: Int) {
        let targets = windows.map { window -> (AXUIElement, pid_t) in
            var pid: pid_t = 0
            AXUIElementGetPid(window, &pid)
            return (window, pid)
        }
        Self.fullScreenQueue.async {
            for (window, pid) in targets {
                guard pid != 0, Self.snapGenerationIsCurrent(generation) else { continue }
                guard self.waitUntilFullScreenExitSettles(window, generation: generation),
                      !self.isFullScreen(window) else { continue }

                let appElement = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(appElement, 0.5)
                let targetFrame = DispatchQueue.main.sync { () -> CGRect? in
                    guard Self.snapGeneration == generation,
                          let windowFrame = self.frame(of: window)
                    else { return nil }
                    return self.maximizeTargetFrame(for: windowFrame, preset: preset)
                }
                guard let targetFrame else { continue }

                DispatchQueue.main.sync {
                    guard Self.snapGeneration == generation,
                          let windowFrame = self.frame(of: window)
                    else { return }
                    Self.restoreStore[Self.windowKey(for: window)] = windowFrame
                }
                guard Self.snapGenerationIsCurrent(generation) else { continue }
                self.setFrame(targetFrame, for: window, on: appElement)
            }
        }
    }

    /// `AXFullScreen` flips to false as soon as the transition starts; wait
    /// for the restored frame to stop moving (or give up and leave the window
    /// alone) so the target screen and restore point are the real ones.
    private func waitUntilFullScreenExitSettles(_ window: AXUIElement, generation: Int) -> Bool {
        let deadline = Date().addingTimeInterval(3)
        var previous: CGRect?
        var stableTicks = 0
        while Date() < deadline {
            guard Self.snapGenerationIsCurrent(generation) else { return false }
            if !isFullScreen(window) {
                let current = frame(of: window)
                if let current, let previous, framesMatch(current, previous) {
                    stableTicks += 1
                    if stableTicks >= 3 { return true }
                } else {
                    stableTicks = 0
                }
                previous = current
            }
            Thread.sleep(forTimeInterval: 0.08)
        }
        return !isFullScreen(window)
    }

    private static func snapGenerationIsCurrent(_ generation: Int) -> Bool {
        if Thread.isMainThread { return snapGeneration == generation }
        return DispatchQueue.main.sync { snapGeneration == generation }
    }

    private func isFullScreen(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    @discardableResult
    private func leaveFullScreen(_ window: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse) == .success
    }

    private static let tilingQueue = DispatchQueue(label: "design.mondary.windows.bento", qos: .userInitiated)
    // Accessed on main only. A new snap command supersedes pending AX work.
    private static var tilingGeneration = 0
    /// Explicit user commands only: Space transitions caused by leaving
    /// fullscreen keep the deferred maximize alive.
    private static var snapGeneration = 0
    private static let tilingCancellationObservers: [NSObjectProtocol] = [
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main) { _ in tilingGeneration += 1 },
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { _ in tilingGeneration += 1 }
    ]

    private struct TileWindow {
        let window: AXUIElement
        let id: CGWindowID
        let frame: CGRect
        let desktop: UInt64
        let rank: Int
    }

    /// Each (desktop, display) gets its own composition and twelve-window cap.
    /// No Space switching or window reassignment is needed for either scope.
    private func tileWindows(scope: BentoTiling.Scope) {
        guard let desktops = SpaceManagementService.desktopSnapshot(),
              scope == .allDesktops || desktops.current != nil else { NSSound.beep(); return }
        let tiles = allTileableWindows(scope: scope, desktops: desktops)
        guard !tiles.isEmpty else { return }
        let generation = Self.tilingGeneration
        let mainHeight = primaryScreenHeight
        var screens: [CanvasWorkspace: [TileWindow]] = [:]
        for tile in tiles {
            guard let screen = screen(for: tile.frame),
                  let displayID = screen.launchpadDisplayID
            else { continue }
            screens[CanvasWorkspace(displayID: displayID, spaceID: tile.desktop), default: []].append(tile)
        }
        let plans = screens.compactMap { workspace, windows -> (CanvasWorkspace, CGRect, [TileWindow])? in
            guard let screen = NSScreen.screen(forDisplayID: workspace.displayID) else { return nil }
            let visible = screen.visibleFrame
            let area = CGRect(x: visible.minX, y: mainHeight - visible.maxY, width: visible.width, height: visible.height)
            return (workspace, area, Array(windows.prefix(CanvasLayout.maximumBentoWindows)))
        }
        Self.tilingQueue.async {
            let valid = { DispatchQueue.main.sync { Self.tilingGeneration == generation } }
            for (workspace, area, windows) in plans {
                guard valid() else { return }
                var saved = Set<Int>()
                let selected = BentoTiling.arrange(in: area, count: windows.count, apply: { index, target in
                    let tile = windows[index]
                    if saved.insert(index).inserted {
                        DispatchQueue.main.sync {
                            if Self.tilingGeneration == generation {
                                Self.restoreStore[Self.windowKey(for: tile.window)] = tile.frame
                            }
                        }
                    }
                    let windowValid = {
                        valid() && SpaceManagementService.desktops(forWindow: tile.id) == [tile.desktop]
                    }
                    let result = CanvasWindowAccess.applyCanvasFrame(target, window: tile.window,
                        requireExactSize: true, valid: windowValid)
                    return result.accepted ? result.actual : nil
                }, restore: { index in
                    let tile = windows[index]
                    _ = CanvasWindowAccess.applyCanvasFrame(tile.frame, window: tile.window, valid: {
                        valid() && SpaceManagementService.desktops(forWindow: tile.id) == [tile.desktop]
                    })
                }, valid: valid)
                // Raising an off-Space window can switch desktops. Only bring
                // forward the bento on desktops that were already visible.
                if desktops.visibleDesktops.contains(workspace.spaceID) {
                    for index in selected.reversed() {
                        guard valid() else { return }
                        let tile = windows[index]
                        guard SpaceManagementService.desktops(forWindow: tile.id) == [tile.desktop] else { continue }
                        CanvasWindowAccess.raise(tile.window)
                    }
                }
            }
        }
    }

    /// Fenêtres carrelables : apps classiques non masquées, fenêtres non
    /// réduites et suffisamment grandes. Une seule passe WindowServer alimente
    /// la réconciliation AX de chaque app (Electron/VSCode inclues). Les
    /// fenêtres de PKwindowsManagement sont exclues : l'action est souvent
    /// déclenchée depuis les réglages, qui ne doit pas se carreler lui-même.
    private func allTileableWindows(scope: BentoTiling.Scope,
                                    desktops: SpaceManagementService.DesktopSnapshot) -> [TileWindow] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && !$0.isHidden
                && $0.processIdentifier != ownPID
        }
        guard !apps.isEmpty else { return [] }

        // Even covered/offscreen windows can belong to the active Space.
        // Exact membership below, not on-screen visibility, defines the scope.
        let infos = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let expectedByPID = CanvasWindowAccess.expectedWindowIDs(in: infos)
        let orderedIDs = infos.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
        let ranks = Dictionary(orderedIDs.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)

        var result: [TileWindow] = []
        for app in apps {
            let pid = app.processIdentifier
            let expectedIDs = expectedByPID[pid] ?? []
            guard !expectedIDs.isEmpty else { continue }
            let windows = CanvasWindowAccess.windows(
                pid: pid,
                expectedWindowIDs: expectedByPID[pid] ?? [],
                reconcile: true
            )
            for window in windows {
                // `eligible` écarte dialogues, fenêtres réduites ou plein
                // écran et fenêtres non déplaçables : la grille ne réserve pas
                // de case pour une fenêtre qui ne bougera pas.
                guard let id = CanvasWindowAccess.id(window), expectedIDs.contains(id),
                      let desktop = BentoTiling.desktop(for: SpaceManagementService.desktops(forWindow: id),
                          scope: scope, current: desktops.current, userDesktops: desktops.userDesktops),
                      CanvasWindowAccess.eligible(window),
                      let windowFrame = frame(of: window),
                      windowFrame.width > 80, windowFrame.height > 80
                else { continue }
                result.append(TileWindow(window: window, id: id, frame: windowFrame,
                                         desktop: desktop, rank: ranks[id] ?? Int.max))
            }
        }
        return result.sorted { $0.rank < $1.rank }
    }

    private func isMinimized(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
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
        case .windowMaximizeAll: .maximizeAll
        case .windowMaximizeAllInApp: .maximizeAllInApp
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
        case .windowTileAll: .tileAll
        case .windowTileAllDesktops: .tileAllDesktops
        case .desktopCreate, .desktopCloseCurrent, .windowNextDesktop, .windowPreviousDesktop,
             .desktopMoveLeft, .desktopMoveRight,
             .canvasToggle, .canvasPrevious, .canvasNext, .canvasRestore,
             .canvasFullHeight, .canvasHalfHeight, .canvasAbove, .canvasBelow,
             .canvasMoveColumnLeft, .canvasMoveColumnRight, .windowSwitcherToggle:
            nil
        }
    }
}
