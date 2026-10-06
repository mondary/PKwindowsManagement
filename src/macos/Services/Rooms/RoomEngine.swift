import AppKit
import ApplicationServices

/// Activates a room: launches the room's apps that aren't running (quietly, in
/// the background), waits until they can offer a window, then lays every window
/// of the room's apps out on the screen the pointer is on — the room's app
/// order decides which window takes which spot, the main window of each app
/// first. Finally lands in the room's first app so the keyboard goes there.
///
/// V1 is deliberately conservative: windows of the room are arranged, nothing
/// else is hidden, parked or closed.
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
        let frame: CGRect
    }

    func activate(_ room: Room) async -> Report {
        guard ensureAccessibilityPermission() else { return Report() }
        var report = Report()

        // 1. Launch the room's apps that aren't running yet.
        for app in room.apps where NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else {
                report.missing.append(app.name)
                continue
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            report.launched.append(app.name)
        }

        // 2. Wait until every app offers at least one window (fresh launches
        //    need a moment; 4 s like the upstream Rooms app).
        let deadline = Date().addingTimeInterval(4)
        var candidates = collectWindows(room: room)
        while candidates.count < room.apps.count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
            candidates = collectWindows(room: room)
        }

        // 3. Lay out on the screen under the pointer.
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return report }
        let visible = screen.visibleFrame
        let axTop = primaryScreenHeight - visible.maxY
        let visibleAX = CGRect(x: visible.minX, y: axTop, width: visible.width, height: visible.height)

        let frames = RoomTiler.frames(count: candidates.count, kind: room.layout, in: visibleAX)
        for (candidate, frame) in zip(candidates, frames) {
            setFrame(frame, for: candidate.element, on: candidate.appElement)
            report.placed += 1
        }

        // 4. Land in the room's first app so typing goes there.
        if let first = room.apps.first,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: first.bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
        return report
    }

    // MARK: Inventory

    /// Standard, non-minimized windows of the room's apps, in room order; within
    /// an app the main window comes first, then the rest front to back.
    private func collectWindows(room: Room) -> [Candidate] {
        var result: [Candidate] = []
        for roomApp in room.apps {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: roomApp.bundleID).first else {
                continue
            }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: AnyObject?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement]
            else { continue }

            var appCandidates: [Candidate] = []
            for element in windows {
                guard let subrole = stringAttribute(kAXSubroleAttribute as CFString, on: element),
                      subrole == kAXStandardWindowSubrole as String
                else { continue }
                if boolAttribute(kAXMinimizedAttribute as CFString, on: element) == true { continue }
                guard let frame = frame(of: element),
                      frame.width >= 100, frame.height >= 60
                else { continue }
                appCandidates.append(Candidate(app: app, element: element, appElement: appElement, frame: frame))
            }
            if let mainIndex = appCandidates.firstIndex(where: {
                boolAttribute(kAXMainAttribute as CFString, on: $0.element) == true
            }) {
                let main = appCandidates.remove(at: mainIndex)
                appCandidates.insert(main, at: 0)
            }
            result.append(contentsOf: appCandidates)
        }
        return result
    }

    // MARK: AX helpers (same patterns as WindowSnapService)

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    private var primaryScreenHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? 0
    }

    private func stringAttribute(_ attribute: CFString, on element: AXUIElement) -> String? {
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else { return nil }
        return value as? String
    }

    private func boolAttribute(_ attribute: CFString, on element: AXUIElement) -> Bool? {
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else { return nil }
        return value as? Bool
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

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, on: window),
              let size = sizeAttribute(kAXSizeAttribute as CFString, on: window)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement, on appElement: AXUIElement) {
        // Apps with enhanced AX (animations) move reluctantly: switch it off for
        // the move, then restore it.
        let enhancedKey = "AXEnhancedUserInterface" as CFString
        var enhancedWasOn = false
        var previous: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, enhancedKey, &previous) == .success,
           let flag = previous as? Bool, flag
        {
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
}
