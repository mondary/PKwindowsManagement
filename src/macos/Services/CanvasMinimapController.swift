import AppKit
import Combine
import SwiftUI

/// Thin OmniWM-style bar floating at the top of every screen running an
/// active horizontal Canvas: the whole strip of columns at a glance, the
/// visible zone highlighted, click a column to travel there. One
/// non-activating panel per display, driven by the service's main-thread
/// snapshots — worker-owned strips are never read here. Clicks do not steal
/// focus from the canvas windows: the panel never becomes key.
final class CanvasMinimapController {
    static let shared = CanvasMinimapController()

    private var panels: [CGDirectDisplayID: NSPanel] = [:]
    private var hosts: [CGDirectDisplayID: NSHostingView<CanvasMinimapBar>] = [:]
    private var subscription: Any?
    /// Injected so this file stays free of settings/runtime dependencies and
    /// remains standalone-typecheckable.
    private var isEnabled: () -> Bool = { true }

    func start(isEnabled: @escaping () -> Bool = { true }) {
        self.isEnabled = isEnabled
        guard subscription == nil else { return }
        subscription = HorizontalCanvasService.shared.$minimaps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] minimaps in self?.render(minimaps) }
    }

    /// Re-apply the enable preference immediately (called from its toggle).
    func refresh() {
        render(HorizontalCanvasService.shared.minimaps)
    }

    // MARK: - Panels (main thread only)

    private func render(_ minimaps: [CGDirectDisplayID: CanvasMinimap.Model]) {
        guard isEnabled() else {
            hideAll()
            return
        }
        for displayID in panels.keys where minimaps[displayID] == nil {
            close(displayID)
        }
        for (displayID, model) in minimaps {
            guard let screen = screen(for: displayID) else {
                close(displayID)
                continue
            }
            let frame = barFrame(on: screen)
            if let panel = panels[displayID], let host = hosts[displayID] {
                host.rootView = CanvasMinimapBar(model: model) { column in
                    HorizontalCanvasService.shared.focusColumn(column, on: displayID)
                }
                panel.setFrame(frame, display: true)
            } else {
                open(model: model, displayID: displayID, frame: frame)
            }
        }
    }

    private func open(model: CanvasMinimap.Model, displayID: CGDirectDisplayID, frame: NSRect) {
        let host = NSHostingView(rootView: CanvasMinimapBar(model: model) { column in
            HorizontalCanvasService.shared.focusColumn(column, on: displayID)
        })
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.setFrame(frame, display: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        host.autoresizingMask = [.width, .height]
        host.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = host
        panels[displayID] = panel
        hosts[displayID] = host
        panel.orderFrontRegardless()
    }

    private func close(_ displayID: CGDirectDisplayID) {
        panels[displayID]?.orderOut(nil)
        panels[displayID] = nil
        hosts[displayID] = nil
    }

    private func hideAll() {
        for displayID in panels.keys { close(displayID) }
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
        }
    }

    /// Centered under the menu bar; wide enough to read a dozen columns
    /// without covering the camera housing zone of the desktop.
    private func barFrame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let width = min(max(320, visible.width * 0.42), 640)
        let height: CGFloat = 34
        return NSRect(
            x: visible.midX - width / 2,
            y: visible.maxY - height,
            width: width,
            height: height
        )
    }
}

/// The bar itself: proportional column cells (two stacked cells for
/// half-height pairs), the selected column accented, and the visible zone
/// outlined on top. No state: every change comes as a new model.
struct CanvasMinimapBar: View {
    let model: CanvasMinimap.Model
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Array(model.segments.enumerated()), id: \.offset) { pair in
                    columnCells(rows: pair.element.rows, selected: model.selectedColumn == pair.offset)
                        .frame(width: max(3, pair.element.length * proxy.size.width - 2), height: nil)
                        .frame(maxHeight: .infinity)
                        .offset(x: pair.element.start * proxy.size.width + 1)
                        .onTapGesture { onSelect(pair.offset) }
                }
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                    .frame(width: max(12, (model.viewportEnd - model.viewportStart) * proxy.size.width))
                    .frame(maxHeight: .infinity)
                    .offset(x: model.viewportStart * proxy.size.width)
                    .allowsHitTesting(false)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 7, bottom: 6, trailing: 7))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15))
                )
        )
    }

    @ViewBuilder
    private func columnCells(rows: Int, selected: Bool) -> some View {
        if rows >= 2 {
            VStack(spacing: 2) {
                cell(selected: selected)
                cell(selected: selected)
            }
        } else {
            cell(selected: selected)
        }
    }

    private func cell(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(selected
                ? Color(nsColor: .controlAccentColor).opacity(0.9)
                : Color.primary.opacity(0.22))
    }
}
