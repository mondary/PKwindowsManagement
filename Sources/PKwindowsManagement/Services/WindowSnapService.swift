import AppKit
import ApplicationServices

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

/// Toutes les géométries sont calculées dans l'espace AX (origine en haut à
/// gauche de l'écran principal, y vers le bas) — le même espace que les
/// positions/taille lues via Accessibility. Les frames NSScreen (origine en
/// bas à gauche) ne servent qu'à la détection d'écran, via une simple
/// translation verticale, jamais mélangées aux calculs de position.
final class WindowSnapService {
    private let restoreStore = WindowRestoreStore()

    func perform(_ action: ShortcutAction, preset: WindowMarginPreset = WindowMarginPreset()) {
        guard permissionGranted() else { return }
        guard let window = focusedWindow(),
              let current = frame(of: window)
        else { return }

        switch action {
        case .windowRestore:
            if let saved = restoreStore.frame(for: window) {
                setFrame(saved, for: window)
            }
            return
        case .windowToggleFullScreen:
            guard let screen = screen(for: current) else { return }
            let full = axFrame(of: screen)
            if framesMatch(current, full) {
                if let saved = restoreStore.frame(for: window) {
                    setFrame(saved, for: window)
                }
            } else {
                restoreStore.remember(window, current)
                setFrame(full, for: window)
            }
            return
        case .windowFullScreen:
            guard let screen = screen(for: current) else { return }
            restoreStore.remember(window, current)
            setFrame(axFrame(of: screen), for: window)
            return
        default:
            break
        }

        guard let screen = screen(for: current) else { return }
        let base = insetFrame(axVisibleFrame(of: screen), by: preset.general)
        guard let target = targetFrame(for: action, current: current, base: base, preset: preset) else { return }
        restoreStore.remember(window, current)
        setFrame(target, for: window)
    }

    private func targetFrame(for action: ShortcutAction, current: CGRect, base: CGRect, preset: WindowMarginPreset) -> CGRect? {
        switch action {
        case .windowLeftHalf:
            return cycleHalf(current: current, base: base, anchor: .left)
        case .windowRightHalf:
            return cycleHalf(current: current, base: base, anchor: .right)
        case .windowTopHalf:
            let h = floor(base.height / 2)
            return CGRect(x: base.minX, y: base.minY, width: base.width, height: h)
        case .windowBottomHalf:
            let h = floor(base.height / 2)
            return CGRect(x: base.minX, y: base.maxY - h, width: base.width, height: h)
        case .windowMaximize:
            return insetFrame(base, by: preset.almostFull)
        case .windowCenter:
            let area = insetFrame(base, by: preset.center)
            let width = min(current.width, area.width)
            let height = min(current.height, area.height)
            return CGRect(x: round(area.midX - width / 2), y: round(area.midY - height / 2), width: round(width), height: round(height))
        case .windowTopLeft:
            return CGRect(x: base.minX, y: base.minY, width: floor(base.width / 2), height: floor(base.height / 2))
        case .windowTopRight:
            return CGRect(x: base.midX, y: base.minY, width: floor(base.width / 2), height: floor(base.height / 2))
        case .windowBottomLeft:
            return CGRect(x: base.minX, y: base.midY, width: floor(base.width / 2), height: floor(base.height / 2))
        case .windowBottomRight:
            return CGRect(x: base.midX, y: base.midY, width: floor(base.width / 2), height: floor(base.height / 2))
        case .windowFirstThird:
            return CGRect(x: base.minX, y: base.minY, width: floor(base.width / 3), height: base.height)
        case .windowCenterThird:
            let w = floor(base.width / 3)
            return CGRect(x: base.minX + w, y: base.minY, width: w, height: base.height)
        case .windowLastThird:
            let w = floor(base.width / 3)
            return CGRect(x: base.maxX - w, y: base.minY, width: w, height: base.height)
        case .windowTopFirstSixth:
            return CGRect(x: base.minX, y: base.minY, width: floor(base.width / 3), height: floor(base.height / 2))
        case .windowTopCenterSixth:
            let w = floor(base.width / 3)
            return CGRect(x: base.minX + w, y: base.minY, width: w, height: floor(base.height / 2))
        case .windowTopLastSixth:
            let w = floor(base.width / 3)
            return CGRect(x: base.maxX - w, y: base.minY, width: w, height: floor(base.height / 2))
        case .windowBottomFirstSixth:
            return CGRect(x: base.minX, y: base.midY, width: floor(base.width / 3), height: floor(base.height / 2))
        case .windowBottomCenterSixth:
            let w = floor(base.width / 3)
            return CGRect(x: base.minX + w, y: base.midY, width: w, height: floor(base.height / 2))
        case .windowBottomLastSixth:
            let w = floor(base.width / 3)
            return CGRect(x: base.maxX - w, y: base.midY, width: w, height: floor(base.height / 2))
        case .windowMaximizeHeight:
            return CGRect(x: current.minX, y: base.minY, width: min(current.width, base.width), height: base.height)
        case .windowMaximizeWidth:
            return CGRect(x: base.minX, y: current.minY, width: base.width, height: min(current.height, base.height))
        case .windowMakeLarger:
            return scaled(current, base: base, factor: 1.15)
        case .windowMakeSmaller:
            return scaled(current, base: base, factor: 0.85)
        case .windowReasonableSize:
            let width = min(base.width * 0.6, 1025)
            let height = min(base.height * 0.6, 900)
            return CGRect(x: round(base.midX - width / 2), y: round(base.midY - height / 2), width: round(width), height: round(height))
        case .windowMoveLeft:
            return clamped(CGRect(x: base.minX, y: current.minY, width: current.width, height: current.height), to: base)
        case .windowMoveRight:
            return clamped(CGRect(x: base.maxX - current.width, y: current.minY, width: current.width, height: current.height), to: base)
        case .windowMoveUp:
            return clamped(CGRect(x: current.minX, y: base.minY, width: current.width, height: current.height), to: base)
        case .windowMoveDown:
            return clamped(CGRect(x: current.minX, y: base.maxY - current.height, width: current.width, height: current.height), to: base)
        case .windowTopThird:
            let h = floor(base.height / 3)
            return CGRect(x: base.minX, y: base.minY, width: base.width, height: h)
        case .windowBottomThird:
            let h = floor(base.height / 3)
            return CGRect(x: base.minX, y: base.maxY - h, width: base.width, height: h)
        case .windowTopTwoThirds:
            let h = floor(base.height * 2 / 3)
            return CGRect(x: base.minX, y: base.minY, width: base.width, height: h)
        case .windowBottomTwoThirds:
            let h = floor(base.height * 2 / 3)
            return CGRect(x: base.minX, y: base.maxY - h, width: base.width, height: h)
        case .windowFirstTwoThirds:
            let w = floor(base.width * 2 / 3)
            return CGRect(x: base.minX, y: base.minY, width: w, height: base.height)
        case .windowCenterTwoThirds:
            let w = floor(base.width / 3)
            return CGRect(x: base.minX + w, y: base.minY, width: w, height: base.height)
        case .windowLastTwoThirds:
            let w = floor(base.width * 2 / 3)
            return CGRect(x: base.maxX - w, y: base.minY, width: w, height: base.height)
        case .windowFirstFourth:
            let w = floor(base.width / 4)
            return CGRect(x: base.minX, y: base.minY, width: w, height: base.height)
        case .windowSecondFourth:
            let w = floor(base.width / 4)
            return CGRect(x: base.minX + w, y: base.minY, width: w, height: base.height)
        case .windowThirdFourth:
            let w = floor(base.width / 4)
            return CGRect(x: base.minX + 2 * w, y: base.minY, width: w, height: base.height)
        case .windowLastFourth:
            let w = floor(base.width / 4)
            return CGRect(x: base.maxX - w, y: base.minY, width: w, height: base.height)
        case .windowFirstThreeFourths:
            let w = floor(base.width * 3 / 4)
            return CGRect(x: base.minX, y: base.minY, width: w, height: base.height)
        case .windowCenterThreeFourths:
            let w = floor(base.width / 4)
            return CGRect(x: base.minX + w, y: base.minY, width: 2 * w, height: base.height)
        case .windowLastThreeFourths:
            let w = floor(base.width * 3 / 4)
            return CGRect(x: base.maxX - w, y: base.minY, width: w, height: base.height)
        case .windowNextDisplay:
            return moveToAnotherDisplay(currentFrame: current, currentScreen: screen(for: current), direction: 1)
        case .windowPreviousDisplay:
            return moveToAnotherDisplay(currentFrame: current, currentScreen: screen(for: current), direction: -1)
        case .windowFullScreen, .windowToggleFullScreen, .windowRestore:
            return nil
        }
    }

    private enum Side { case left, right }

    private static var cycleIndex: [String: Int] = [:]
    private static var cycleTime: [String: Date] = [:]

    /// Cycle ½ → ⅔ → ⅓ via un minuteur de 3 s par côté. Robuste aux apps qui
    /// remontent une taille légèrement différente de celle demandée (le
    /// matching strict de frame partait en vrille sur ces apps).
    private func cycleHalf(current: CGRect, base: CGRect, anchor: Side) -> CGRect {
        let halfWidth = floor(base.width / 2.0)
        let thirdWidth = floor(base.width / 3.0)
        let twoThirdsWidth = floor(base.width * 2.0 / 3.0)

        let candidates: [CGRect]
        switch anchor {
        case .left:
            candidates = [
                CGRect(x: base.minX, y: base.minY, width: halfWidth, height: base.height),
                CGRect(x: base.minX, y: base.minY, width: twoThirdsWidth, height: base.height),
                CGRect(x: base.minX, y: base.minY, width: thirdWidth, height: base.height),
            ]
        case .right:
            candidates = [
                CGRect(x: base.maxX - halfWidth, y: base.minY, width: halfWidth, height: base.height),
                CGRect(x: base.maxX - twoThirdsWidth, y: base.minY, width: twoThirdsWidth, height: base.height),
                CGRect(x: base.maxX - thirdWidth, y: base.minY, width: thirdWidth, height: base.height),
            ]
        }

        let key = anchor == .left ? "left" : "right"
        let now = Date()
        let lastTime = Self.cycleTime[key] ?? .distantPast
        let withinWindow = now.timeIntervalSince(lastTime) <= 3.0

        let nextIndex: Int
        if withinWindow {
            let stored = Self.cycleIndex[key] ?? 0
            nextIndex = (stored + 1) % candidates.count
        } else if let matched = candidates.firstIndex(where: { cycleMatches($0, current, reference: base.width) }) {
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
        return abs(candidate.width - current.width) <= tolerance
            && abs(candidate.minX - current.minX) <= tolerance
            && abs(candidate.height - current.height) <= tolerance
            && abs(candidate.minY - current.minY) <= tolerance
    }

    private func scaled(_ current: CGRect, base: CGRect, factor: CGFloat) -> CGRect {
        let width = min(max(200, current.width * factor), base.width)
        let height = min(max(160, current.height * factor), base.height)
        return CGRect(x: round(current.midX - width / 2), y: round(current.midY - height / 2), width: round(width), height: round(height))
    }

    private func clamped(_ frame: CGRect, to base: CGRect) -> CGRect {
        var f = frame
        f.size.width = min(f.width, base.width)
        f.size.height = min(f.height, base.height)
        f.origin.x = min(max(f.minX, base.minX), base.maxX - f.width)
        f.origin.y = min(max(f.minY, base.minY), base.maxY - f.height)
        return f
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

    private func framesMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 2 && abs(lhs.minY - rhs.minY) <= 2 &&
            abs(lhs.width - rhs.width) <= 2 && abs(lhs.height - rhs.height) <= 2
    }

    // MARK: - Écrans

    /// Hauteur de l'écran principal (menu bar) : c'est la référence verticale
    /// de l'espace AX. Tous les écrans sont alignés par le haut en AX.
    private var mainScreenHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? 0
    }

    private func axVisibleFrame(of screen: NSScreen) -> CGRect {
        let v = screen.visibleFrame
        return CGRect(x: v.minX, y: mainScreenHeight - v.maxY, width: v.width, height: v.height)
    }

    private func axFrame(of screen: NSScreen) -> CGRect {
        let f = screen.frame
        return CGRect(x: f.minX, y: mainScreenHeight - f.maxY, width: f.width, height: f.height)
    }

    /// L'écran est choisi par la plus grande intersection entre le frame AX de
    /// la fenêtre et le frame AX de chaque écran. Pas de dépendance à la
    /// position du curseur ni à un écran "principal" arbitraire.
    private func screen(for frame: CGRect) -> NSScreen? {
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let area = axFrame(of: screen).intersection(frame).width * axFrame(of: screen).intersection(frame).height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best
    }

    private func moveToAnotherDisplay(currentFrame: CGRect, currentScreen: NSScreen?, direction: Int) -> CGRect? {
        let screens = NSScreen.screens
        guard screens.count > 1,
              let currentScreen,
              let index = screens.firstIndex(where: { $0 === currentScreen })
        else { return nil }
        let next = screens[(index + direction + screens.count) % screens.count]
        let current = axVisibleFrame(of: currentScreen)
        let target = axVisibleFrame(of: next)

        let width = min(target.width, max(280, round(currentFrame.width * target.width / current.width)))
        let height = min(target.height, max(220, round(currentFrame.height * target.height / current.height)))
        let xRatio = current.width > 0 ? (currentFrame.minX - current.minX) / current.width : 0.2
        let yRatio = current.height > 0 ? (currentFrame.minY - current.minY) / current.height : 0.2
        var x = target.minX + round((target.width - width) * xRatio)
        var y = target.minY + round((target.height - height) * yRatio)
        x = min(max(x, target.minX), target.maxX - width)
        y = min(max(y, target.minY), target.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Accessibility

    private func permissionGranted() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        return false
    }

    /// Chrome/Chromium/Electron ne construisent leur arbre Accessibility que
    /// si une techno d'assistance le réclame. Sans ça, les fenêtres Chrome ne
    /// répondent ni à kAXPosition ni à kAXSize (le raccourci ne fait rien).
    /// `AXManualAccessibility` est le flag Chromium ; `AXEnhancedUserInterface`
    /// couvre le reste. C'est le correctif qu'utilisent Raycast, Rectangle, etc.
    /// Sans effet sur les apps qui ne reconnaissent pas ces attributs.
    private func primeAccessibility(_ app: AXUIElement) {
        let truth = kCFBooleanTrue as CFTypeRef
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, truth)
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, truth)
    }

    private func focusedWindow() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var appRef: AnyObject?
        let appStatus = AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &appRef)
        guard appStatus == .success, let appElement = appRef as! AXUIElement? else { return nil }

        primeAccessibility(appElement)

        var windowRef: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
           let window = windowRef as! AXUIElement? {
            return window
        }

        // Chrome peut construire son arbre AX de façon asynchrone après le
        // prime ; on retente une fois la fenêtre focusée.
        var windowRef2: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef2) == .success,
           let window = windowRef2 as! AXUIElement? {
            return window
        }

        // Fallback pour les apps qui ne remontent pas de fenêtre "focusée".
        var mainRef: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainRef) == .success,
           let main = mainRef as! AXUIElement? {
            return main
        }
        var windowsRef: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement],
           let first = windows.first {
            return first
        }
        return nil
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, on: window),
              let size = sizeAttribute(kAXSizeAttribute as CFString, on: window)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Taille d'abord, position ensuite : l'inverse laissait certaines apps
    /// repositionner la fenêtre pendant le resize (Almost Maximize partait en
    /// vrille). La position finale gagne.
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
}

/// Se souvient du frame précédent de chaque fenêtre pour Restore et le toggle
/// plein écran. La clé est stable : CFHash est cohérent avec CFEqual, et deux
/// AXUIElement créés séparément pour la même fenêtre sont égaux.
final class WindowRestoreStore {
    static let shared = WindowRestoreStore()
    private var frames: [CFHashCode: CGRect] = [:]

    func remember(_ element: AXUIElement, _ frame: CGRect) {
        frames[CFHash(element)] = frame
    }

    func frame(for element: AXUIElement) -> CGRect? {
        frames[CFHash(element)]
    }
}
