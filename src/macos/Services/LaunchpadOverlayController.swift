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

    func toggle(settings: AppSettings) {
        if panel?.isVisible == true {
            hide()
        } else {
            show(settings: settings)
        }
    }

    func show(settings: AppSettings) {
        guard panel?.isVisible != true else { return }
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
        let targetScreen = screenForCurrentPointer() ?? NSScreen.main
        let rootView = CompactLaunchpadRootView(settings: settings)
        let hosting = NSHostingController(rootView: rootView)

        let compactSize = NSSize(width: 600, height: 460)
        let screenFrame = targetScreen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screenFrame.midX - compactSize.width / 2,
            y: screenFrame.midY - compactSize.height / 2
        )
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
        panel.isMovable = false

        hosting.view.frame = NSRect(origin: .zero, size: compactSize)
        hosting.view.autoresizingMask = [.width, .height]
        panel.contentView = hosting.view

        self.host = hosting
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        host = nil
    }

    func openSettings() {
        hide()
        DispatchQueue.main.async {
            if let settingsWindow = NSApp.windows.first(where: { $0.title == "PKwindowsManagement" }) {
                settingsWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            AppRuntime.shared.openSettings?()
        }
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
