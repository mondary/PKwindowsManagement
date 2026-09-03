import AppKit
import SwiftUI

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
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func openSettings() {
        hide()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let settingsWindow = NSApp.windows.first(where: { $0.title == "PKwindowsManagement" && $0.isVisible }) {
                if settingsWindow.isMiniaturized {
                    settingsWindow.deminiaturize(nil)
                }
                settingsWindow.makeKeyAndOrderFront(nil)
                return
            }
            // Fenêtre fermée ou non restaurée au lancement : réouvrir le bundle
            // de l'app en cours envoie l'Apple Event `reopen` et SwiftUI recrée
            // la fenêtre du WindowGroup, sans dépendre d'une closure SwiftUI.
            NSWorkspace.shared.open(Bundle.main.bundleURL)
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
