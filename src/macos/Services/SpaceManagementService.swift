import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation
import ObjectiveC
import OSLog

private let spacesLogger = Logger(subsystem: "com.mondary.PKwindowsManagement", category: "Spaces")

/// Actions on macOS virtual desktops (Spaces).
enum SpaceAction: String, CaseIterable, Identifiable {
    case createDesktop
    case closeCurrentDesktop
    case moveWindowToNextDesktop
    case moveWindowToPreviousDesktop
    case moveDesktopLeft
    case moveDesktopRight

    var id: String { rawValue }
}

/// Options captured on the main thread before dispatching a space action.
struct SpaceActionOptions {
    var wallpaperFolder: URL?
    var wallpaperOnCreate = true
    var followMovedWindow = true
}

/// AppKit screen/window context captured on the main thread before the private
/// API work is dispatched to the service queue.
private struct SpaceScreenSnapshot {
    struct Display {
        let id: CGDirectDisplayID
        let uuid: String
        let frame: CGRect
    }

    let displays: [Display]
    let frontmostPID: pid_t?

    static func capture() -> SpaceScreenSnapshot {
        let read = {
            let displays = NSScreen.screens.compactMap { screen -> Display? in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                    return nil
                }
                guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(id) else { return nil }
                let uuid = CFUUIDCreateString(kCFAllocatorDefault, unmanagedUUID.takeRetainedValue()) as String
                return Display(id: id, uuid: uuid, frame: screen.frame)
            }
            return SpaceScreenSnapshot(
                displays: displays,
                frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier
            )
        }
        if Thread.isMainThread { return read() }
        return DispatchQueue.main.sync { read() }
    }

    func displayID(forUUID uuid: String) -> CGDirectDisplayID? {
        displays.first { $0.uuid.caseInsensitiveCompare(uuid) == .orderedSame }?.id
    }

    func displayID(intersecting windowFrame: CGRect) -> CGDirectDisplayID? {
        guard let best = displays.max(by: {
            Self.intersectionArea($0.frame, windowFrame) < Self.intersectionArea($1.frame, windowFrame)
        }), Self.intersectionArea(best.frame, windowFrame) > 0 else { return nil }
        return best.id
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return max(0, intersection.width) * max(0, intersection.height)
    }
}

/// Keyboard-driven Spaces management: create/close desktops, move the focused
/// window to an adjacent desktop and assign a random wallpaper to new desktops.
///
/// macOS exposes no public API for any of this. Like Hammerspoon and yabai
/// (both credited in the app's Credits section), this service combines:
/// - private SkyLight functions (loaded with dlsym, no hard link) for reading
///   spaces and moving windows — silent, no Mission Control flash;
/// - Mission Control driven through the WindowManager/Dock accessibility tree
///   for creating and closing desktops — a brief flash is unavoidable.
///
/// Everything degrades gracefully: if a private symbol disappears after a
/// macOS update, actions no-op with a console log instead of crashing.
final class SpaceManagementService {
    static let shared = SpaceManagementService()

    private let workQueue = DispatchQueue(label: "pk.windows-management.spaces", qos: .userInitiated)
    private var busy = false
    private var lastWallpaperPath: String?
    private var lastFollowFailureTime: TimeInterval = 0

    private let wallpaperExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "bmp"]

    // MARK: - Entry point

    func perform(_ action: SpaceAction, options: SpaceActionOptions) {
        spacesLogger.notice("Action received: \(action.rawValue, privacy: .public)")
        let requestedAt = ProcessInfo.processInfo.systemUptime
        workQueue.async { [weak self] in
            guard let self else { return }
            if action == .moveWindowToNextDesktop || action == .moveWindowToPreviousDesktop,
               requestedAt <= self.lastFollowFailureTime {
                spacesLogger.error("Queued move cancelled after a failed focus restoration")
                return
            }
            guard !self.busy else { return }
            self.busy = true
            defer { self.busy = false }

            // A second shortcut can arrive during Mission Control. Read its
            // context only after the previous move has restored window focus.
            let screens = SpaceScreenSnapshot.capture()

            switch action {
            case .createDesktop:
                self.createDesktop(options: options, screens: screens)
            case .closeCurrentDesktop:
                self.closeCurrentDesktop(screens: screens)
            case .moveWindowToNextDesktop:
                self.moveFocusedWindow(toNext: true, options: options, screens: screens)
            case .moveWindowToPreviousDesktop:
                self.moveFocusedWindow(toNext: false, options: options, screens: screens)
            case .moveDesktopLeft:
                self.reorderDesktop(toNext: false, screens: screens)
            case .moveDesktopRight:
                self.reorderDesktop(toNext: true, screens: screens)
            }
        }
    }

    // MARK: - Create desktop (+ random wallpaper)

    private func createDesktop(options: SpaceActionOptions, screens: SpaceScreenSnapshot) {
        guard let sls = SLSBridge.shared else { fail("SkyLight unavailable"); return }
        guard let activeSpace = sls.activeSpaceID(),
              let activeDisplay = sls.managedDisplays()?.first(where: { $0.spaceIDs.contains(activeSpace) })
        else { return }
        guard let displayID = screens.displayID(forUUID: activeDisplay.uuid) else {
            fail("Could not identify the active display")
            return
        }
        guard activeDisplay.types.filter({ $0 == 0 }).count < 16 else { beep(); return }
        let originalUserSpaceCount = activeDisplay.types.filter { $0 == 0 }.count

        let created = runInMissionControl(closesItself: true) { mc in
            guard let display = self.displayGroup(in: mc, displayID: displayID),
                  let spaces = self.spacesGroup(in: display),
                  let list = self.child("mc.spaces.list", of: spaces)
            else { return false }

            let originalCount = self.children(list).count
            guard let addButton = self.child("mc.spaces.add", of: spaces),
                  self.performAction(addButton, action: "AXPress")
            else { return false }

            guard let thumbnails = self.waitForDesktopThumbnails(
                displayID: displayID,
                minimumCount: originalCount + 1,
                timeout: 2
            ), let target = thumbnails.last
            else { return false }

            // Mission Control orders desktops left-to-right; the added one is
            // appended at the far right. Selecting it makes it the active Space.
            return self.performAction(target, action: "AXPress")
        }
        guard created else { fail("Could not create or select the new desktop"); return }
        guard waitForNewActiveSpace(
            onDisplay: activeDisplay.uuid,
            previousSpace: activeSpace,
            expectedUserSpaceCount: originalUserSpaceCount + 1,
            timeout: 2
        ) else {
            fail("The new desktop was not confirmed as active")
            return
        }

        guard options.wallpaperOnCreate, let folder = options.wallpaperFolder else { return }
        guard let createdSpace = sls.activeSpaceID(), createdSpace != activeSpace else {
            NSLog("PKwindowsManagement: wallpaper skipped because the newly created desktop could not be confirmed active")
            return
        }
        Thread.sleep(forTimeInterval: 0.35)
        guard sls.activeSpaceID() == createdSpace else {
            NSLog("PKwindowsManagement: wallpaper skipped because the active desktop changed")
            return
        }
        applyRandomWallpaper(from: folder, displayID: displayID)
    }

    // MARK: - Close current desktop

    private func closeCurrentDesktop(screens: SpaceScreenSnapshot) {
        guard let sls = SLSBridge.shared else { fail("SkyLight unavailable"); return }
        guard let displays = sls.managedDisplays(),
              let active = sls.activeSpaceID(),
              let display = displays.first(where: { $0.spaceIDs.contains(active) }),
              let index = display.spaceIDs.firstIndex(of: active)
        else { return }

        // Safety: never close a fullscreen/tiled space or the last user desktop.
        guard display.types[index] == 0 else { return }
        guard display.types.filter({ $0 == 0 }).count >= 2 else { beep(); return }

        guard let displayID = screens.displayID(forUUID: display.uuid) else {
            fail("Could not identify the active display")
            return
        }
        let neighborIndex = (1..<display.spaceIDs.count)
            .flatMap { distance in [index + distance, index - distance] }
            .first { candidate in
                candidate >= 0
                    && candidate < display.spaceIDs.count
                    && display.types[candidate] == 0
            }
        guard let neighborIndex else { beep(); return }

        // macOS does not allow removing the active desktop. First switch to a
        // neighboring user desktop, then reopen Mission Control and remove the
        // former current desktop by its original strip index.
        let switched = runInMissionControl(closesItself: true) { mc in
            guard let displayGroup = self.displayGroup(in: mc, displayID: displayID),
                  let spaces = self.spacesGroup(in: displayGroup)
            else { return false }
            let thumbs = self.desktopThumbnails(spaces)
            guard thumbs.count == display.spaceIDs.count, index < thumbs.count else {
                NSLog("PKwindowsManagement: desktop switch aborted (AX strip mismatch: %d vs %d)", thumbs.count, display.spaceIDs.count)
                return false
            }
            return self.performAction(thumbs[neighborIndex], action: "AXPress")
        }
        guard switched else { fail("Could not switch away from the current desktop"); return }
        Thread.sleep(forTimeInterval: 0.35)
        guard sls.activeSpaceID() != active else { fail("The current desktop is still active"); return }

        let removed = runInMissionControl(closesItself: false) { mc in
            guard let displayGroup = self.displayGroup(in: mc, displayID: displayID),
                  let spaces = self.spacesGroup(in: displayGroup)
            else { return false }
            let thumbs = self.desktopThumbnails(spaces)
            guard thumbs.count == display.spaceIDs.count,
                  index < thumbs.count,
                  sls.activeSpaceID() != active
            else {
                NSLog("PKwindowsManagement: close desktop aborted (AX strip changed)")
                return false
            }
            return self.performAction(thumbs[index], action: "AXRemoveDesktop")
        }
        guard removed else { fail("Could not close the previous desktop"); return }
        guard waitForSpaceRemoval(active, timeout: 2) else {
            fail("The previous desktop still exists")
            return
        }
    }

    // MARK: - Move focused window to adjacent desktop

    private func moveFocusedWindow(toNext: Bool, options: SpaceActionOptions, screens: SpaceScreenSnapshot) {
        guard let sls = SLSBridge.shared else { fail("SkyLight unavailable"); return }
        guard let windowID = focusedWindowID(frontmostPID: screens.frontmostPID) else {
            fail("Could not identify the focused window")
            return
        }
        guard let windowSpaces = sls.spaces(forWindow: windowID)
        else {
            fail("Could not read the focused window's desktop")
            return
        }
        guard !windowSpaces.isEmpty else {
            fail("No desktop found for the focused window")
            return
        }
        guard windowSpaces.count == 1, let sourceSpace = windowSpaces.first else {
            fail("This window belongs to more than one desktop")
            return
        }
        guard
              let displays = sls.managedDisplays(),
              let display = displays.first(where: { $0.spaceIDs.contains(sourceSpace) }),
              let sourceIndex = display.spaceIDs.firstIndex(of: sourceSpace)
        else {
            fail("Could not identify the active display and desktop")
            return
        }
        // With separate Spaces on each monitor, the global active Space can
        // belong to another display. Use the focused window's own desktop.
        guard display.currentSpaceID == sourceSpace, display.types[sourceIndex] == 0 else {
            fail("The focused window is not on a visible user desktop")
            return
        }
        let sourceDisplayID = screens.displayID(forUUID: display.uuid)
            ?? windowScreenID(windowID, using: screens)

        let step: Int = toNext ? 1 : -1
        var targetIndex: Int?
        var index = sourceIndex + step
        while index >= 0, index < display.spaceIDs.count {
            if display.types[index] == 0 { targetIndex = index; break }
            index += step
        }
        guard let targetIndex else {
            fail("There is no adjacent desktop in that direction")
            return
        }
        let targetSpace = display.spaceIDs[targetIndex]
        // Retain the exact AX window before moving it off the current desktop.
        // Activating only its app could select another window of that same app.
        let focusTarget = options.followMovedWindow ? windowFocusTarget(windowID) : nil
        if options.followMovedWindow, focusTarget == nil {
            fail("Could not retain the focused window for desktop follow-up")
            return
        }
        spacesLogger.notice("Move window \(windowID) from \(sourceSpace) to \(targetSpace)")

        guard sls.moveWindow(windowID, toSpace: targetSpace) else {
            fail("Could not move the window to the adjacent desktop")
            return
        }
        guard options.followMovedWindow else { return }
        var focusRestored = false
        defer {
            // Never let already queued shortcuts move an unrelated window if
            // following or restoring focus failed. A fresh shortcut can retry.
            if !focusRestored { lastFollowFailureTime = ProcessInfo.processInfo.systemUptime }
        }

        guard let displayID = sourceDisplayID else {
            NSLog("PKwindowsManagement: window moved, but the source display could not be identified for follow-up")
            return
        }
        let followed = runInMissionControl(closesItself: true) { mc in
            guard let displayGroup = self.displayGroup(in: mc, displayID: displayID),
                  let spaces = self.spacesGroup(in: displayGroup)
            else { return false }
            let thumbs = self.desktopThumbnails(spaces)
            guard thumbs.count == display.spaceIDs.count, targetIndex < thumbs.count else {
                NSLog("PKwindowsManagement: follow move aborted (AX strip mismatch)")
                return false
            }
            return self.performAction(thumbs[targetIndex], action: "AXPress")
        }
        guard followed else {
            fail("Window moved, but could not switch to its destination desktop")
            return
        }
        guard let focusTarget,
              restoreFocus(focusTarget, onSpace: targetSpace, displayUUID: display.uuid, sls: sls)
        else {
            fail("Window moved, but its focus could not be restored on the destination desktop")
            return
        }
        spacesLogger.notice("Focus restored to moved window \(windowID) on desktop \(targetSpace)")
        focusRestored = true
    }

    private struct WindowFocusTarget {
        let id: CGWindowID
        let pid: pid_t
        let app: AXUIElement
        let window: AXUIElement
    }

    private func windowFocusTarget(_ windowID: CGWindowID) -> WindowFocusTarget? {
        guard let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]])?
            .first(where: { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID }),
              let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
        else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var candidates: [AXUIElement] = []
        if let focused = value(app, kAXFocusedWindowAttribute as String).flatMap({ axElement($0) }) {
            candidates.append(focused)
        }
        if let windows = value(app, kAXWindowsAttribute as String) as? [AXUIElement] {
            candidates.append(contentsOf: windows)
        }
        guard let window = candidates.first(where: { AXWindowIDBridge.windowID($0) == windowID }) else {
            return nil
        }
        return WindowFocusTarget(id: windowID, pid: pid, app: app, window: window)
    }

    /// Runs on the serial service queue. Mission Control can restore the old
    /// desktop's key window after AXPress succeeds, so confirm a settled arrival
    /// before raising the moved window and verifying its actual AX focus.
    private func restoreFocus(
        _ target: WindowFocusTarget, onSpace spaceID: UInt64, displayUUID: String, sls: SLSBridge
    ) -> Bool {
        let arrivalDeadline = ProcessInfo.processInfo.systemUptime + 3
        var settledSince: TimeInterval?
        func destinationIsActive() -> Bool {
            sls.managedDisplays()?.first(where: {
                $0.uuid.caseInsensitiveCompare(displayUUID) == .orderedSame
            })?.currentSpaceID == spaceID
        }
        while ProcessInfo.processInfo.systemUptime < arrivalDeadline {
            let now = ProcessInfo.processInfo.systemUptime
            if destinationIsActive(), missionControlGroup() == nil {
                if settledSince == nil { settledSince = now }
                if now - (settledSince ?? now) >= 0.25 { break }
            } else {
                settledSince = nil
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard let settledSince, ProcessInfo.processInfo.systemUptime - settledSince >= 0.25,
              destinationIsActive(), missionControlGroup() == nil
        else { return false }

        let focusDeadline = ProcessInfo.processInfo.systemUptime + 2
        var focusedSince: TimeInterval?
        while ProcessInfo.processInfo.systemUptime < focusDeadline {
            guard destinationIsActive(), missionControlGroup() == nil,
                  sls.spaces(forWindow: target.id) == [spaceID],
                  AXWindowIDBridge.windowID(target.window) == target.id
            else { return false }
            let frontmostPID = DispatchQueue.main.sync {
                NSWorkspace.shared.frontmostApplication?.processIdentifier
            }
            let focusedID = value(target.app, kAXFocusedWindowAttribute as String)
                .flatMap { axElement($0) }.flatMap { AXWindowIDBridge.windowID($0) }
            let now = ProcessInfo.processInfo.systemUptime
            if frontmostPID == target.pid, focusedID == target.id {
                if focusedSince == nil { focusedSince = now }
                if now - (focusedSince ?? now) >= 0.25 { return true }
            } else {
                focusedSince = nil
                AXUIElementSetAttributeValue(target.window, kAXMainAttribute as CFString, kCFBooleanTrue)
                DispatchQueue.main.sync {
                    _ = NSRunningApplication(processIdentifier: target.pid)?.activate(options: [.activateIgnoringOtherApps])
                }
                AXUIElementPerformAction(target.window, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(target.app, kAXFocusedWindowAttribute as CFString, target.window)
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    // MARK: - Reorder native desktops

    private func reorderDesktop(toNext: Bool, screens: SpaceScreenSnapshot) {
        guard let sls = SLSBridge.shared, let active = sls.activeSpaceID(),
              let display = sls.managedDisplays()?.first(where: { $0.currentSpaceID == active }),
              let source = display.spaceIDs.firstIndex(of: active), display.types[source] == 0,
              let displayID = screens.displayID(forUUID: display.uuid)
        else { fail("Could not identify the desktop to reorder"); return }
        let step = toNext ? 1 : -1
        var destination = source + step
        while display.spaceIDs.indices.contains(destination), display.types[destination] != 0 {
            destination += step
        }
        guard let expected = DesktopOrder.moving(display.spaceIDs, from: source, to: destination) else {
            fail("There is no neighboring desktop to reorder past")
            return
        }
        let focus = focusedWindowID(frontmostPID: screens.frontmostPID).flatMap { windowFocusTarget($0) }
        let reordered = runInMissionControl(closesItself: false) { mc in
            guard let group = self.displayGroup(in: mc, displayID: displayID),
                  let spaces = self.spacesGroup(in: group),
                  sls.managedDisplays()?.first(where: { $0.uuid == display.uuid })?.spaceIDs == display.spaceIDs
            else { return false }
            let thumbs = self.desktopThumbnails(spaces)
            guard thumbs.count == display.spaceIDs.count,
                  let from = self.accessibilityFrame(thumbs[source]),
                  let to = self.accessibilityFrame(thumbs[destination])
            else { return false }
            // AXPress switches desktops; only dragging the native thumbnail
            // changes their order. No window is reassigned to a different Space.
            guard self.dragDesktopThumbnail(
                from: CGPoint(x: from.midX, y: from.midY),
                to: CGPoint(x: toNext ? to.maxX - 8 : to.minX + 8, y: to.midY)
            ) else { return false }
            let deadline = ProcessInfo.processInfo.systemUptime + 2
            while ProcessInfo.processInfo.systemUptime < deadline {
                if sls.managedDisplays()?.first(where: { $0.uuid == display.uuid })?.spaceIDs == expected {
                    return true
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            return false
        }
        guard reordered else { fail("Desktop order was not confirmed after dragging its thumbnail"); return }
        // Selecting the original ID at its new index keeps the same desktop active.
        if sls.managedDisplays()?.first(where: { $0.uuid == display.uuid })?.currentSpaceID != active {
            let selected = runInMissionControl(closesItself: true) { mc in
                guard sls.managedDisplays()?.first(where: { $0.uuid == display.uuid })?.spaceIDs == expected,
                      let group = self.displayGroup(in: mc, displayID: displayID),
                      let spaces = self.spacesGroup(in: group) else { return false }
                let thumbs = self.desktopThumbnails(spaces)
                guard thumbs.count == expected.count else { return false }
                return self.performAction(thumbs[destination], action: "AXPress")
            }
            guard selected else { fail("Desktop reordered, but could not return to it"); return }
        }
        if let focus, !restoreFocus(focus, onSpace: active, displayUUID: display.uuid, sls: sls) {
            fail("Desktop reordered, but could not restore window focus")
            return
        }
        guard sls.managedDisplays()?.first(where: { $0.uuid == display.uuid })?.spaceIDs == expected else {
            fail("Desktop order changed again; check automatic Spaces rearrangement in macOS")
            return
        }
        spacesLogger.notice("Reordered desktop \(active) from index \(source) to \(destination)")
    }

    private func accessibilityFrame(_ element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute as String),
              let size = value(element, kAXSizeAttribute as String),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &dimensions),
              dimensions.width > 16, dimensions.height > 16 else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    private func dragDesktopThumbnail(from start: CGPoint, to end: CGPoint) -> Bool {
        guard let source = CGEventSource(stateID: .privateState),
              let previous = CGEvent(source: nil)?.location,
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left)
        else { return false }
        defer {
            up.post(tap: .cghidEventTap)
            CGWarpMouseCursorPosition(previous)
        }
        CGWarpMouseCursorPosition(start)
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.15)
        for index in 1...24 {
            let fraction = CGFloat(index) / 24
            let point = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
            guard let event = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left) else { return false }
            event.flags = []
            event.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.02)
        }
        return true
    }

    // MARK: - Wallpaper

    private func applyRandomWallpaper(from folder: URL, displayID: CGDirectDisplayID) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey]
        ))?.filter {
            wallpaperExtensions.contains($0.pathExtension.lowercased())
                && ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true)
        } ?? []
        guard !files.isEmpty else { return }

        // Avoid picking the same image twice in a row when there is a choice.
        let candidates = files.count > 1 ? files.filter { $0.path != lastWallpaperPath } : files
        guard let pick = candidates.randomElement() else { return }
        lastWallpaperPath = pick.path

        DispatchQueue.main.sync {
            guard let screen = NSScreen.screens.first(where: {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
            }) else { return }
            do {
                // The API applies the image to the currently active Space on
                // this screen, which is why selection happens before this call.
                try NSWorkspace.shared.setDesktopImageURL(pick, for: screen, options: [
                    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true
                ])
            } catch {
                NSLog("PKwindowsManagement: wallpaper assignment failed: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - Mission Control (Accessibility)

    /// Opens Mission Control, waits for its AX tree, runs `body`, then closes
    /// it unless the body itself closed it (pressing a desktop thumbnail makes
    /// Mission Control dismiss itself).
    @discardableResult
    private func runInMissionControl(closesItself: Bool, _ body: (AXUIElement) -> Bool) -> Bool {
        if missionControlGroup() == nil {
            CoreDockBridge.sendNotification("com.apple.expose.awake")
        }
        guard let mc = waitForMissionControlGroup(timeout: 2.0) else {
            NSLog("PKwindowsManagement: Mission Control AX tree unavailable")
            return false
        }
        // Mission Control needs a moment before its elements accept actions
        // (same MCwaitTime trade-off as Hammerspoon).
        Thread.sleep(forTimeInterval: 0.35)

        let success = body(mc)

        if closesItself, success {
            Thread.sleep(forTimeInterval: 0.25)
            if missionControlGroup() != nil {
                CoreDockBridge.sendNotification("com.apple.expose.awake")
            }
        } else {
            Thread.sleep(forTimeInterval: 0.3)
            if missionControlGroup() != nil {
                CoreDockBridge.sendNotification("com.apple.expose.awake")
            }
        }
        return success
    }

    private func missionControlGroup() -> AXUIElement? {
        // macOS 27 leaves an empty `mc` stub under Dock and exposes the live
        // tree directly under WindowManager. Prefer that tree, then fall back
        // to Dock on older releases.
        for bundleID in ["com.apple.WindowManager", "com.apple.dock"] {
            guard let app = applicationElement(bundleID: bundleID) else { continue }
            if let mc = child("mc", of: app), hasDisplayGroups(in: mc) { return mc }
            if hasDisplayGroups(in: app) { return app }
        }
        return nil
    }

    private func applicationElement(bundleID: String) -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
              app.processIdentifier != 0
        else { return nil }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    private func hasDisplayGroups(in element: AXUIElement) -> Bool {
        children(element).contains { identifier(of: $0) == "mc.display" }
    }

    private func waitForMissionControlGroup(timeout: TimeInterval) -> AXUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let group = missionControlGroup() { return group }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return nil
    }

    private func displayGroup(in missionControl: AXUIElement, displayID: CGDirectDisplayID) -> AXUIElement? {
        for group in children(missionControl) {
            guard identifier(of: group) == "mc.display" else { continue }
            if number(of: group, attribute: "AXDisplayID") == Int(displayID) {
                return group
            }
        }
        return nil
    }

    private func spacesGroup(in displayGroup: AXUIElement) -> AXUIElement? {
        child("mc.spaces", of: displayGroup)
    }

    /// Desktop thumbnails of the strip ("mc.spaces.list") for one display.
    private func desktopThumbnails(_ spacesGroup: AXUIElement) -> [AXUIElement] {
        guard let list = child("mc.spaces.list", of: spacesGroup) else { return [] }
        return children(list)
    }

    private func waitForDesktopThumbnails(
        displayID: CGDirectDisplayID,
        minimumCount: Int,
        timeout: TimeInterval
    ) -> [AXUIElement]? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let mc = missionControlGroup(),
               let display = displayGroup(in: mc, displayID: displayID),
               let spaces = spacesGroup(in: display)
            {
                let thumbnails = desktopThumbnails(spaces)
                if thumbnails.count >= minimumCount { return thumbnails }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return nil
    }

    private func waitForNewActiveSpace(
        onDisplay displayUUID: String,
        previousSpace: UInt64,
        expectedUserSpaceCount: Int,
        timeout: TimeInterval
    ) -> Bool {
        guard let sls = SLSBridge.shared else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let active = sls.activeSpaceID(),
               active != previousSpace,
               let display = sls.managedDisplays()?.first(where: {
                   $0.uuid.caseInsensitiveCompare(displayUUID) == .orderedSame
               }),
               display.spaceIDs.contains(active),
               display.types.filter({ $0 == 0 }).count == expectedUserSpaceCount
            {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    private func waitForSpaceRemoval(_ spaceID: UInt64, timeout: TimeInterval) -> Bool {
        guard let sls = SLSBridge.shared else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let displays = sls.managedDisplays(),
               !displays.contains(where: { $0.spaceIDs.contains(spaceID) })
            {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    private func child(_ targetIdentifier: String, of parent: AXUIElement) -> AXUIElement? {
        children(parent).first { identifier(of: $0) == targetIdentifier }
    }

    private func performAction(_ element: AXUIElement, action: String) -> Bool {
        let status = AXUIElementPerformAction(element, action as CFString)
        if status != .success {
            NSLog("PKwindowsManagement: AX action %@ failed (%d)", action, status.rawValue)
            return false
        }
        return true
    }

    // MARK: - AX plumbing

    private func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success else { return nil }
        return raw
    }

    private func children(_ element: AXUIElement) -> [AXUIElement] {
        guard let raw = value(element, "AXChildren"),
              CFGetTypeID(raw) == CFArrayGetTypeID()
        else { return [] }
        let array = unsafeBitCast(raw, to: NSArray.self)
        return array.compactMap { axElement($0) }
    }

    private func axElement(_ value: Any) -> AXUIElement? {
        let cfValue = value as CFTypeRef
        guard CFGetTypeID(cfValue) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeBitCast(cfValue, to: AXUIElement.self)
    }

    private func identifier(of element: AXUIElement) -> String? {
        value(element, "AXIdentifier") as? String
    }

    private func number(of element: AXUIElement, attribute: String) -> Int? {
        (value(element, attribute) as? NSNumber)?.intValue
    }

    // MARK: - Focused window & screens

    /// CGWindowID of the focused window, using Accessibility's window mapping
    /// first and the frontmost application's top-level window as fallback.
    private func focusedWindowID(frontmostPID: pid_t?) -> UInt32? {
        let systemWide = AXUIElementCreateSystemWide()
        var candidates: [AXUIElement] = []

        var focusedRaw: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemWide, "AXFocusedUIElement" as CFString, &focusedRaw) == .success,
           let focused = focusedRaw.flatMap({ axElement($0) })
        {
            candidates.append(focused)
        }
        var windowRaw: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemWide, "AXFocusedWindow" as CFString, &windowRaw) == .success,
           let window = windowRaw.flatMap({ axElement($0) })
        {
            candidates.append(window)
        }

        for element in candidates {
            var windowElements = [element]
            if let window = value(element, kAXWindowAttribute as String).flatMap({ axElement($0) }) {
                windowElements.insert(window, at: 0)
            }
            for windowElement in windowElements {
                if let windowID = AXWindowIDBridge.windowID(windowElement) { return windowID }
            }
        }

        guard let pid = frontmostPID,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        for info in list {
            let ownerPID = info[kCGWindowOwnerPID as String] as? Int ?? -1
            let layer = info[kCGWindowLayer as String] as? Int ?? 99
            if ownerPID == pid, layer == 0, let windowID = info[kCGWindowNumber as String] as? Int {
                return UInt32(windowID)
            }
        }
        return nil
    }

    private func windowScreenID(_ windowID: CGWindowID, using screens: SpaceScreenSnapshot) -> CGDirectDisplayID? {
        guard
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]],
              let info = list.first(where: { ($0[kCGWindowNumber as String] as? Int) == Int(windowID) }),
              let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? CGFloat, let y = bounds["Y"] as? CGFloat,
              let width = bounds["Width"] as? CGFloat, let height = bounds["Height"] as? CGFloat
        else { return nil }
        let desktopTop = screens.displays.map(\.frame.maxY).max() ?? 0
        let frame = CGRect(x: x, y: desktopTop - y - height, width: width, height: height)
        return screens.displayID(intersecting: frame)
    }

    // MARK: - Feedback

    private func beep() {
        DispatchQueue.main.async { NSSound.beep() }
    }

    private func fail(_ message: String) {
        spacesLogger.error("\(message, privacy: .public)")
        beep()
    }
}

/// `AXUIElementGetWindow` is an undocumented symbol exported by macOS. Rooms
/// already uses the same runtime lookup; resolving it dynamically keeps the
/// app loadable if Apple removes it in a future release.
private enum AXWindowIDBridge {
    private typealias GetWindowFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private static let getWindow: GetWindowFunction? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let symbol = dlsym(handle, "_AXUIElementGetWindow")
        else { return nil }
        return unsafeBitCast(symbol, to: GetWindowFunction.self)
    }()

    static func windowID(_ element: AXUIElement) -> CGWindowID? {
        guard let getWindow else { return nil }
        var id: CGWindowID = 0
        return getWindow(element, &id) == .success && id != 0 ? id : nil
    }
}

// MARK: - SkyLight private bridge

/// Private SkyLight functions resolved with dlsym at first use. Symbols have
/// been stable across macOS releases for years (same ones Hammerspoon and
/// yabai rely on), but a missing symbol degrades to a logged no-op instead
/// of a link error.
private final class SLSBridge {
    static let shared: SLSBridge? = SLSBridge()

    struct DisplaySpaces {
        let uuid: String
        let spaceIDs: [UInt64]
        let types: [Int]
        let currentSpaceID: UInt64
    }

    let cid: Int32

    private let copyManagedDisplaySpacesFn: @convention(c) (Int32) -> Unmanaged<CFArray>?
    private let getActiveSpaceFn: @convention(c) (Int32) -> UInt64
    private let copySpacesForWindowsFn: @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private let spaceSetCompatIDFn: (@convention(c) (Int32, UInt64, Int32) -> Int32)?
    private let setWindowListWorkspaceFn: (@convention(c) (Int32, UnsafePointer<UInt32>, Int32, Int32) -> Int32)?
    private let moveWindowsToManagedSpaceFn: (@convention(c) (Int32, CFArray, UInt64) -> Void)?
    private let performBridgedMoveFn: (@convention(c) (AnyObject) -> Int64)?

    private init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let mainConnection = dlsym(handle, "SLSMainConnectionID"),
              let copyManaged = dlsym(handle, "SLSCopyManagedDisplaySpaces"),
              let getActive = dlsym(handle, "SLSGetActiveSpace"),
              let spacesForWindows = dlsym(handle, "SLSCopySpacesForWindows")
        else { return nil }

        cid = unsafeBitCast(mainConnection, to: (@convention(c) () -> Int32).self)()
        copyManagedDisplaySpacesFn = unsafeBitCast(copyManaged, to: (@convention(c) (Int32) -> Unmanaged<CFArray>?).self)
        getActiveSpaceFn = unsafeBitCast(getActive, to: (@convention(c) (Int32) -> UInt64).self)
        copySpacesForWindowsFn = unsafeBitCast(spacesForWindows, to: (@convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?).self)
        spaceSetCompatIDFn = dlsym(handle, "SLSSpaceSetCompatID").map {
            unsafeBitCast($0, to: (@convention(c) (Int32, UInt64, Int32) -> Int32).self)
        }
        setWindowListWorkspaceFn = dlsym(handle, "SLSSetWindowListWorkspace").map {
            unsafeBitCast($0, to: (@convention(c) (Int32, UnsafePointer<UInt32>, Int32, Int32) -> Int32).self)
        }
        moveWindowsToManagedSpaceFn = dlsym(handle, "SLSMoveWindowsToManagedSpace").map {
            unsafeBitCast($0, to: (@convention(c) (Int32, CFArray, UInt64) -> Void).self)
        }
        let bridgedMove = dlsym(handle, "SLSPerformAsynchronousBridgedWindowManagementOperation")
            ?? LoadedMachOSymbol.find(
                "__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation",
                in: "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"
            )
        performBridgedMoveFn = bridgedMove.map {
            unsafeBitCast($0, to: (@convention(c) (AnyObject) -> Int64).self)
        }
        spacesLogger.notice("SkyLight bridged move resolved: \(bridgedMove != nil)")
    }

    func managedDisplays() -> [DisplaySpaces]? {
        guard let unmanaged = copyManagedDisplaySpacesFn(cid) else { return nil }
        let raw = unmanaged.takeRetainedValue()
        guard let entries = raw as? [[String: Any]] else { return nil }
        return entries.compactMap { entry in
            guard let uuid = entry["Display Identifier"] as? String else { return nil }
            let spaces = (entry["Spaces"] as? [[String: Any]]) ?? []
            let parsedSpaces: [(id: UInt64, type: Int)] = spaces.compactMap { space in
                guard let id = (space["ManagedSpaceID"] as? NSNumber)?.uint64Value,
                      let type = (space["type"] as? NSNumber)?.intValue
                else { return nil }
                return (id, type)
            }
            let spaceIDs = parsedSpaces.map(\.id)
            let types = parsedSpaces.map(\.type)
            let current = (entry["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? NSNumber
            return DisplaySpaces(
                uuid: uuid,
                spaceIDs: spaceIDs,
                types: types,
                currentSpaceID: current?.uint64Value ?? spaceIDs.first ?? 0
            )
        }
    }

    func activeSpaceID() -> UInt64? {
        let sid = getActiveSpaceFn(cid)
        return sid != 0 ? sid : nil
    }

    func spaces(forWindow windowID: UInt32) -> [UInt64]? {
        guard let unmanaged = copySpacesForWindowsFn(cid, 0x7, windowNumberArray([windowID])) else { return nil }
        let raw = unmanaged.takeRetainedValue()
        let array = unsafeBitCast(raw, to: NSArray.self)
        return array.compactMap { ($0 as? NSNumber)?.uint64Value }
    }

    /// Prefer yabai's bridged operation on modern macOS, with the older
    /// compat-ID path as fallback. Confirm membership after either call.
    @discardableResult
    func moveWindow(_ windowID: UInt32, toSpace sid: UInt64) -> Bool {
        if Self.isMacOS14_5OrNewer {
            if moveWindowWithBridgedOperation(windowID, toSpace: sid),
               waitForWindow(windowID, onSpace: sid, timeout: 1.2)
            {
                return true
            }

            // Older/private compatibility path. macOS 27 may report a zero
            // CGError while leaving the window unmoved, so status alone never
            // counts as success below.
            let workspace: Int32 = 0x7961_6265 // "yabe" magic, as used by yabai
            guard let setCompatID = spaceSetCompatIDFn,
                  let setWindowWorkspace = setWindowListWorkspaceFn,
                  setCompatID(cid, sid, workspace) == 0
            else { return false }
            var wid = windowID
            let status = setWindowWorkspace(cid, &wid, 1, workspace)
            _ = setCompatID(cid, sid, 0)
            guard status == 0 else { return false }
        } else {
            guard let moveWindowsToManagedSpaceFn else { return false }
            moveWindowsToManagedSpaceFn(cid, windowNumberArray([windowID]), sid)
        }
        return waitForWindow(windowID, onSpace: sid, timeout: 1.2)
    }

    /// Match yabai's signed 32-bit window identifiers at the CF boundary.
    private func windowNumberArray(_ windowIDs: [UInt32]) -> CFArray {
        windowIDs.map { NSNumber(value: Int32(bitPattern: $0)) } as CFArray
    }

    private func moveWindowWithBridgedOperation(_ windowID: UInt32, toSpace sid: UInt64) -> Bool {
        guard let perform = performBridgedMoveFn,
              let operationClass = NSClassFromString("SLSBridgedMoveWindowsToManagedSpaceOperation")
        else { return false }

        typealias Allocate = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
        let allocateSelector = sel_registerName("alloc")
        guard let allocateMethod = class_getClassMethod(operationClass, allocateSelector) else { return false }
        let allocate = unsafeBitCast(method_getImplementation(allocateMethod), to: Allocate.self)
        guard let allocated = allocate(operationClass, allocateSelector) else { return false }
        typealias Initialize = @convention(c) (AnyObject, Selector, NSArray, UInt64) -> Unmanaged<AnyObject>?
        let initSelector = sel_registerName("initWithWindows:spaceID:")
        guard let initMethod = class_getInstanceMethod(operationClass, initSelector) else {
            allocated.release()
            return false
        }
        let initialize = unsafeBitCast(method_getImplementation(initMethod), to: Initialize.self)
        let windows = windowNumberArray([windowID]) as NSArray
        guard let operation = initialize(
            // init consumes alloc's +1; adopt the initialized object only once.
            allocated.takeUnretainedValue(),
            initSelector,
            windows,
            sid
        )?.takeRetainedValue() else { return false }

        let result = perform(operation)
        spacesLogger.notice("SkyLight bridged operation returned \(result)")
        return true
    }

    private func waitForWindow(_ windowID: UInt32, onSpace sid: UInt64, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if spaces(forWindow: windowID)?.contains(sid) == true { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    private static var isMacOS14_5OrNewer: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion > 14 { return true }
        if version.majorVersion == 14 { return version.minorVersion >= 5 }
        return false
    }
}

// MARK: - CoreDock notifications (Mission Control toggle)

/// CoreDockSendNotification lives in the public ApplicationServices framework
/// but is not declared in headers; resolved at runtime like Hammerspoon does.
private enum CoreDockBridge {
    private static let handle = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
        RTLD_LAZY
    )

    static func sendNotification(_ name: String) {
        guard let handle, let symbol = dlsym(handle, "CoreDockSendNotification") else {
            NSLog("PKwindowsManagement: CoreDockSendNotification unavailable")
            return
        }
        typealias Fn = @convention(c) (CFString, Int32) -> Int32
        let fn = unsafeBitCast(symbol, to: Fn.self)
        _ = fn(name as CFString, 0)
    }
}
