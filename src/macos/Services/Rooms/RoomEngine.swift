import AppKit
import ApplicationServices

/// Activates a room: launches the room's apps that aren't running (quietly, in
/// the background), waits until their windows appear, then matches each slot to
/// a live window — window ID first, then exact title, similar title, any window
/// of the app — and lays the matched windows out on the screen under the
/// pointer. Windows of the room that stay unmatched leave their spot empty;
/// nothing is ever hidden, parked or closed (v1 stays conservative).
final class RoomEngine {
    struct Report: Equatable {
        var placed = 0
        var launched: [String] = []
        var missing: [String] = []
    }

    private struct Candidate {
        let app: NSRunningApplication
        let element: AXUIElement
        let appElement: AXUIElement
        let info: RoomLiveWindow
        let isMinimized: Bool
    }

    /// A window offered by the picker: everything the UI needs, nothing AX-bound.
    struct WindowOffer: Identifiable, Hashable {
        let windowID: UInt32?
        let bundleID: String
        let appName: String
        let title: String

        var id: String { "\(windowID.map(String.init) ?? "x")|\(bundleID)|\(title)" }

        var pick: RoomLiveWindow { RoomLiveWindow(bundleID: bundleID, title: title, windowID: windowID) }
    }

    // MARK: Activation

    func activate(_ room: Room, claimed: Set<UInt32> = []) async -> Report {
        guard ensureAccessibilityPermission() else { return Report() }
        var report = Report()

        // 1. Launch the room's apps that aren't running yet, in slot order.
        var launchedIDs = Set<String>()
        for bundleID in room.appBundleIDs
        where NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                report.missing.append(bundleID)
                continue
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            launchedIDs.insert(bundleID)
            if let name = room.windows.first(where: { $0.bundleID == bundleID })?.appName {
                report.launched.append(name)
            }
        }

        // 2. Match slots to live windows; while a just-launched app hasn't
        //    offered a window for a missing slot, keep trying (4 s max).
        var candidates = inventory()
        var assignment = RoomSlotMatcher.assign(slots: room.windows, windows: candidates.map(\.info), claimed: claimed)
        let waitingForLaunch = room.windows.indices.contains {
            assignment[$0] == nil && launchedIDs.contains(room.windows[$0].bundleID)
        }
        if waitingForLaunch {
            let deadline = Date().addingTimeInterval(4)
            while Date() < deadline {
                try? await Task.sleep(nanoseconds: 100_000_000)
                candidates = inventory()
                assignment = RoomSlotMatcher.assign(slots: room.windows, windows: candidates.map(\.info), claimed: claimed)
                if assignment.count == room.windows.count { break }
            }
        }

        // 3. Compute one frame per slot and place every matched window in it.
        var placedNames: [String] = []
        if let screen = targetScreen() {
            let visible = screen.visibleFrame
            let axTop = primaryScreenHeight - visible.maxY
            let visibleAX = CGRect(x: visible.minX, y: axTop, width: visible.width, height: visible.height)
            let frames = RoomTiler.frames(count: room.windows.count, kind: room.layout, in: visibleAX)
            for (slotIndex, windowIndex) in assignment.sorted(by: { $0.key < $1.key }) {
                guard frames.indices.contains(slotIndex),
                      let candidate = candidates[safe: windowIndex]
                else { continue }
                if candidate.isMinimized {
                    setBool(kAXMinimizedAttribute as CFString, false, on: candidate.element)
                }
                setFrame(frames[slotIndex], for: candidate.element, on: candidate.appElement)
                report.placed += 1
                placedNames.append(candidate.info.title.isEmpty ? candidate.app.localizedName ?? "" : candidate.info.title)
            }
        }

        // 4. Report the slots nothing matched.
        for index in room.windows.indices where assignment[index] == nil {
            let slot = room.windows[index]
            if !launchedIDs.contains(slot.bundleID) {
                report.missing.append(slot.title.isEmpty ? slot.appName : slot.title)
            }
        }

        // 5. Land in the room's first app so typing goes there.
        if let first = room.windows.first,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: first.bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
        return report
    }

    // MARK: Inventory

    /// Every standard window of every regular app, including minimized ones —
    /// what the picker offers and what slots match against.
    private func inventory() -> [Candidate] {
        var result: [Candidate] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app != NSRunningApplication.current {
            guard let bundleID = app.bundleIdentifier else { continue }
            let appElement = applicationElement(app.processIdentifier)
            let elements = windowElements(appElement)
            for element in elements {
                let subrole = stringAttribute(kAXSubroleAttribute as CFString, on: element)
                let minimized = boolAttribute(kAXMinimizedAttribute as CFString, on: element) ?? false
                // Windows of hidden or minimized apps report AXDialog for a
                // while; a real document window still has a minimize button.
                let hasMinimizeButton = attribute(kAXMinimizeButtonAttribute as CFString, on: element) != nil
                let isStandard = subrole == kAXStandardWindowSubrole as String
                    || (subrole == kAXDialogSubrole as String && (app.isHidden || minimized || hasMinimizeButton))
                guard isStandard,
                      let frame = frame(of: element),
                      frame.width >= 100, frame.height >= 60
                else { continue }
                result.append(Candidate(
                    app: app,
                    element: element,
                    appElement: appElement,
                    info: RoomLiveWindow(
                        bundleID: bundleID,
                        title: stringAttribute(kAXTitleAttribute as CFString, on: element) ?? "",
                        windowID: windowID(of: element)
                    ),
                    isMinimized: minimized
                ))
            }
        }
        return result
    }

    /// Windows on screen right now, for the room picker.
    func windowOffers() -> [WindowOffer] {
        inventory().map { candidate in
            WindowOffer(
                windowID: candidate.info.windowID,
                bundleID: candidate.info.bundleID,
                appName: candidate.app.localizedName ?? candidate.info.bundleID,
                title: candidate.info.title
            )
        }
    }

    // MARK: AX helpers (patterns shared with WindowSnapService and the
    // upstream Rooms app's AX.swift, MIT)

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    private func applicationElement(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        // A hung app must never freeze us (the default timeout is ~6 s).
        AXUIElementSetMessagingTimeout(element, 0.5)
        return element
    }

    private func windowElements(_ appElement: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let array = value as? [AnyObject]
        else { return [] }
        return array.map { $0 as! AXUIElement }
    }

    private func attribute(_ attribute: CFString, on element: AXUIElement) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value
    }

    private func stringAttribute(_ attribute: CFString, on element: AXUIElement) -> String? {
        attribute(attribute, on: element) as? String
    }

    private func boolAttribute(_ attribute: CFString, on element: AXUIElement) -> Bool? {
        attribute(attribute, on: element) as? Bool
    }

    private func pointAttribute(_ attribute: CFString, on element: AXUIElement) -> CGPoint? {
        guard let axValue = attribute(attribute, on: element),
              CFGetTypeID(axValue) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        let converted = AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return converted ? point : nil
    }

    private func sizeAttribute(_ attribute: CFString, on element: AXUIElement) -> CGSize? {
        guard let axValue = attribute(attribute, on: element),
              CFGetTypeID(axValue) == AXValueGetTypeID()
        else { return nil }
        var size = CGSize.zero
        let converted = AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return converted ? size : nil
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, on: window),
              let size = sizeAttribute(kAXSizeAttribute as CFString, on: window)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func setBool(_ attribute: CFString, _ value: Bool, on element: AXUIElement) {
        AXUIElementSetAttributeValue(element, attribute, value ? kCFBooleanTrue : kCFBooleanFalse)
    }

    /// The window-server ID for an AX window, via the private
    /// `_AXUIElementGetWindow` every macOS window manager uses. Looked up at
    /// runtime so a future macOS without it degrades to title matching instead
    /// of crashing. Ported from the upstream Rooms app's AX.swift (MIT).
    private func windowID(of element: AXUIElement) -> UInt32? {
        guard let getWindow = RoomEngine.getWindowFunction else { return nil }
        var id: CGWindowID = 0
        return getWindow(element, &id) == .success && id != 0 ? id : nil
    }

    private typealias GetWindowFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private static let getWindowFunction: GetWindowFunction? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let symbol = dlsym(handle, "_AXUIElementGetWindow")
        else { return nil }
        return unsafeBitCast(symbol, to: GetWindowFunction.self)
    }()

    /// Size, then position, then size again: macOS clamps size to the display a
    /// window is currently on, so a move to another display needs the second
    /// resize. Enhanced-AX apps move reluctantly: switch off for the move.
    private func setFrame(_ frame: CGRect, for window: AXUIElement, on appElement: AXUIElement) {
        let enhancedKey = "AXEnhancedUserInterface" as CFString
        var enhancedWasOn = false
        if let previous = attribute(enhancedKey, on: appElement) as? Bool, previous {
            enhancedWasOn = true
            AXUIElementSetAttributeValue(appElement, enhancedKey, kCFBooleanFalse)
        }

        var size = frame.size
        var point = frame.origin
        guard let sizeValue1 = AXValueCreate(.cgSize, &size),
              let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue2 = AXValueCreate(.cgSize, &size)
        else { return }

        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue1)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue2)

        if enhancedWasOn {
            AXUIElementSetAttributeValue(appElement, enhancedKey, kCFBooleanTrue)
        }
    }

    private var primaryScreenHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? 0
    }

    private func targetScreen() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main ?? NSScreen.screens.first
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
