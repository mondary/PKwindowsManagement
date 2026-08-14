import AppKit
import SwiftUI

private final class BigYearPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

final class BigYearOverlayController {
    static let shared = BigYearOverlayController()

    private var panel: NSPanel?
    private var host: NSHostingController<BigYearRootView>?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show(year: Int = Calendar.current.component(.year, from: Date())) {
        guard panel?.isVisible != true else { return }
        guard let settings = AppRuntime.shared.settings else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? .zero
        let rootView = BigYearRootView(
            year: year,
            settings: settings,
            onClose: { [weak self] in
            self?.hide()
        })
        let hosting = NSHostingController(rootView: rootView)
        let panel = BigYearPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.setFrame(screenFrame, display: true)
        panel.isOpaque = true
        panel.backgroundColor = .white
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.onEscape = { [weak self] in self?.hide() }
        hosting.view.frame = NSRect(origin: .zero, size: screenFrame.size)
        hosting.view.autoresizingMask = [.width, .height]
        panel.contentView = hosting.view

        self.host = hosting
        self.panel = panel
        installEventMonitor()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        removeEventMonitor()
        panel?.orderOut(nil)
        panel = nil
        host = nil
    }

    private func installEventMonitor() {
        removeEventMonitor()
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            guard self.panel?.isVisible == true else { return event }

            if event.keyCode == 53 { // Escape
                self.hide()
                return nil
            }

            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 12: // Q
                    NSApp.terminate(nil)
                    return nil
                case 13: // W
                    self.hide()
                    return nil
                default:
                    break
                }
            }

            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard event.keyCode == 53 else { return }
            DispatchQueue.main.async { self?.hide() }
        }
    }

    private func removeEventMonitor() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }
}
