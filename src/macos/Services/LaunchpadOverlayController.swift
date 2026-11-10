import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted every time the launchpad overlay becomes visible — whether the
    /// panel was created or reused — so the live views can reset their search
    /// state and focus the field. Without it, a reused panel would reopen
    /// with the previous query and without keyboard focus.
    static let launchpadDidShow = Notification.Name("PKLaunchpadDidShow")
}

private final class LaunchpadPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class LaunchpadOverlayController {
    static let shared = LaunchpadOverlayController()

    private var panel: NSPanel?
    private var host: NSViewController?
    private var style: LaunchpadStyle?
    private var moveObserver: NSObjectProtocol?
    private var previousFrontmostApp: NSRunningApplication?
    private var focusHandoffWorkItem: DispatchWorkItem?

    private static let compactOriginXKey = "launchpad-compact-origin-x"
    private static let compactOriginYKey = "launchpad-compact-origin-y"

    func toggle(settings: AppSettings) {
        if panel?.isVisible == true {
            hide()
        } else {
            show(settings: settings)
        }
    }

    func show(settings: AppSettings) {
        guard panel?.isVisible != true else { return }
        rememberFrontmostAppForHandoff()
        if style == settings.launchpadStyle, let panel {
            let targetScreen = screenForCurrentPointer() ?? NSScreen.main
            if style == .compact {
                // Reprendre la position choisie par l'utilisateur (sinon centré)
                let size = panel.frame.size
                panel.setFrame(
                    NSRect(origin: compactOrigin(size: size), size: size),
                    display: true
                )
            } else if let screenFrame = targetScreen?.frame {
                panel.setFrame(screenFrame, display: true)
                if let hosting = host as? NSHostingController<LaunchpadOverlayRootView> {
                    hosting.rootView = LaunchpadOverlayRootView(
                        settings: settings,
                        displayID: targetScreen?.launchpadDisplayID
                    )
                }
            }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            announceShow()
            return
        }
        panel = nil
        host = nil
        if let observer = moveObserver {
            NotificationCenter.default.removeObserver(observer)
            moveObserver = nil
        }
        style = settings.launchpadStyle
        if settings.launchpadStyle == .compact {
            showCompact(settings: settings)
        } else {
            showFullscreen(settings: settings)
        }
    }

    /// The live SwiftUI content listens for this to drop the previous query
    /// and re-focus the search field: reopening must behave like Spotlight,
    /// not like a window brought back with its old state.
    private func announceShow() {
        NotificationCenter.default.post(name: .launchpadDidShow, object: nil)
    }

    /// Remember who had the keyboard before the overlay took it, so closing
    /// the overlay without launching anything can hand focus back.
    private func rememberFrontmostAppForHandoff() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return }
        previousFrontmostApp = frontmost
    }

    private func showFullscreen(settings: AppSettings) {
        let targetScreen = screenForCurrentPointer() ?? NSScreen.main
        let rootView = LaunchpadOverlayRootView(
            settings: settings,
            displayID: targetScreen?.launchpadDisplayID
        )
        let hosting = NSHostingController(rootView: rootView)
        let screenFrame = targetScreen?.frame ?? NSScreen.main?.frame ?? .zero
        let panel = LaunchpadPanel(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.setFrame(screenFrame, display: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        hosting.view.frame = NSRect(origin: .zero, size: screenFrame.size)
        hosting.view.autoresizingMask = [.width, .height]
        panel.contentView = hosting.view

        self.host = hosting
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        announceShow()
    }

    private func showCompact(settings: AppSettings) {
        let rootView = CompactLaunchpadRootView(settings: settings)
        let hosting = NSHostingController(rootView: rootView)

        let compactSize = NSSize(width: 600, height: 460)
        let origin = compactOrigin(size: compactSize)
        let panel = LaunchpadPanel(
            contentRect: NSRect(origin: origin, size: compactSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = true

        hosting.view.frame = NSRect(origin: .zero, size: compactSize)
        hosting.view.autoresizingMask = [.width, .height]
        panel.contentView = hosting.view

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            guard let self, let frame = self.panel?.frame else { return }
            UserDefaults.standard.set(frame.origin.x, forKey: Self.compactOriginXKey)
            UserDefaults.standard.set(frame.origin.y, forKey: Self.compactOriginYKey)
        }

        self.host = hosting
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        announceShow()
    }

    func hide() {
        panel?.orderOut(nil)
        scheduleFocusHandoff()
    }

    /// Closing the overlay activated at show time would otherwise leave this
    /// app frontmost with no visible window — and the global shortcut
    /// monitor deliberately ignores launch shortcuts while our own app is
    /// active, so Fn⇧M-style shortcuts would stay dead until the user
    /// clicks another app. Hand focus back to whoever had it before.
    /// The check is deferred briefly so a launch fired on close (Mail,
    /// settings window, Rooms overlay…) wins the focus race naturally.
    private func scheduleFocusHandoff() {
        focusHandoffWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.handOffFocusIfNeeded()
        }
        focusHandoffWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func handOffFocusIfNeeded() {
        guard panel?.isVisible != true,
              NSApp.isActive,
              !NSApp.windows.contains(where: { $0.isVisible && $0 !== panel })
        else { return }
        if let previous = previousFrontmostApp,
           !previous.isTerminated,
           previous.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: previous)
                return
            }
        }
        NSApp.deactivate()
    }

    func openSettings() {
        hide()
        DispatchQueue.main.async {
            SettingsWindowController.shared.showSettings()
        }
    }

    /// Position d'ouverture du panneau compact : celle choisie par
    /// l'utilisateur (limitée à l'écran où elle se trouve), sinon centré
    /// sur l'écran sous le pointeur.
    private func compactOrigin(size: NSSize) -> NSPoint {
        if let saved = savedCompactOrigin,
           let savedScreen = NSScreen.screens.first(where: { $0.visibleFrame.contains(saved) }) {
            let visible = savedScreen.visibleFrame
            return NSPoint(
                x: min(max(saved.x, visible.minX), visible.maxX - size.width),
                y: min(max(saved.y, visible.minY), visible.maxY - size.height)
            )
        }
        let visibleFrame = screenForCurrentPointer()?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        return NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
    }

    private var savedCompactOrigin: NSPoint? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.compactOriginXKey) != nil else { return nil }
        return NSPoint(
            x: defaults.double(forKey: Self.compactOriginXKey),
            y: defaults.double(forKey: Self.compactOriginYKey)
        )
    }

    private func screenForCurrentPointer() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) }
    }
}

struct LaunchpadOverlayRootView: View {
    @ObservedObject var settings: AppSettings
    let displayID: CGDirectDisplayID?

    var body: some View {
        LaunchpadOverlayView(settings: settings, displayID: displayID)
            .environment(\.locale, settings.appLanguage.locale)
            .id(settings.appLanguage)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.08, blue: 0.25).opacity(0.98),
                        Color(red: 0.12, green: 0.16, blue: 0.38).opacity(0.96),
                        Color(red: 0.02, green: 0.04, blue: 0.14).opacity(0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
