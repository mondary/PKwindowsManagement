import AppKit
import Combine
import SwiftUI

/// Thin OmniWM-style bar floating at the top or bottom edge of every screen running an
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
    private var iconCache: [pid_t: NSImage] = [:]
    /// Injected so this file stays free of settings/runtime dependencies and
    /// remains standalone-typecheckable.
    private var isEnabled: () -> Bool = { true }
    private var isAtBottom: () -> Bool = { false }

    func start(isEnabled: @escaping () -> Bool = { true },
               isAtBottom: @escaping () -> Bool = { false }) {
        self.isEnabled = isEnabled
        self.isAtBottom = isAtBottom
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
            let placement = CanvasMinimap.barPlacement(
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame,
                hasNotch: screen.safeAreaInsets.top > 0,
                atBottom: isAtBottom()
            )
            let level: NSWindow.Level = placement.overlaysMenuBar ? .statusBar : .floating
            if let panel = panels[displayID], let host = hosts[displayID] {
                host.rootView = barView(model: model, displayID: displayID)
                panel.level = level
                panel.setFrame(placement.frame, display: true)
            } else {
                open(model: model, displayID: displayID, frame: placement.frame)
                panels[displayID]?.level = level
            }
        }
    }

    private func open(model: CanvasMinimap.Model, displayID: CGDirectDisplayID, frame: NSRect) {
        let host = MinimapHostingView(rootView: barView(model: model, displayID: displayID))
        let panel = MinimapPanel(
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

    private func barView(model: CanvasMinimap.Model, displayID: CGDirectDisplayID) -> CanvasMinimapBar {
        CanvasMinimapBar(model: model, onSelect: { column in
            HorizontalCanvasService.shared.focusColumn(column, on: displayID)
        }, onMove: { column, target in
            HorizontalCanvasService.shared.moveColumn(column, to: target, on: displayID)
        }, icon: { [weak self] pid in self?.appIcon(for: pid) })
    }

    /// Main-thread icon resolution with a bounded cache; pid 0 = none.
    private func appIcon(for pid: pid_t) -> NSImage? {
        guard pid != 0 else { return nil }
        if let cached = iconCache[pid] { return cached }
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon?.copy() as? NSImage else { return nil }
        icon.size = NSSize(width: 24, height: 24)
        if iconCache.count > 96 { iconCache.removeAll() }
        iconCache[pid] = icon
        return icon
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

}

/// The first click must navigate, not activate the hosting view first.
private final class MinimapHostingView: NSHostingView<CanvasMinimapBar> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private final class MinimapPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Proportional app-icon cells, selected-column accent and a thin viewport
/// rule. No state: every change comes as a new model.
struct CanvasMinimapBar: View {
    let model: CanvasMinimap.Model
    let onSelect: (Int) -> Void
    /// Menu-bar-style reorder: long press a segment, drag, drop onto another
    /// column. Fractions live in the bar's own coordinate space.
    var onMove: (Int, Int) -> Void = { _, _ in }
    /// App icon for an owning pid, resolved (and cached) on the main thread.
    var icon: (pid_t) -> NSImage? = { _ in nil }

    @State private var reorder: (source: Int, target: Int)?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Array(model.segments.enumerated()), id: \.offset) { pair in
                    segmentCapsule(index: pair.offset, segment: pair.element, size: proxy.size)
                }
                // Visible zone: a thin top rule instead of a heavy outline.
                Rectangle()
                    .fill(Color.clear)
                    .overlay(alignment: .top) {
                        Capsule().fill(Color.accentColor.opacity(0.85)).frame(height: 2)
                    }
                    .frame(width: max(0, (model.viewportEnd - model.viewportStart) * proxy.size.width))
                    .frame(maxHeight: .infinity)
                    .offset(x: model.viewportStart * proxy.size.width)
                    .allowsHitTesting(false)
                // Insertion indicator while dragging a segment.
                if let reorder, reorder.target != reorder.source,
                   model.segments.indices.contains(reorder.target) {
                    let segment = model.segments[reorder.target]
                    let edge = reorder.target > reorder.source ? segment.start + segment.length : segment.start
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 2)
                        .offset(x: edge * proxy.size.width - 1)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "canvasMinimapBar")
        }
        .padding(EdgeInsets(top: 4, leading: 6, bottom: 3, trailing: 6))
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.92)
        )
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
    }

    /// Each column is a distinct hit target, without minimum-width overlap.
    /// Tap travels to the column; long press then drag — the menu-bar icon
    /// gesture — reorders it. The pair travels as one column.
    private func segmentCapsule(index: Int, segment: CanvasMinimap.Segment, size: CGSize) -> some View {
        let selected = model.selectedColumn == index
        let frame = segment.frame(in: size)
        let images = segment.pids.compactMap(icon)
        let names = segment.pids.compactMap {
            NSRunningApplication(processIdentifier: $0)?.localizedName
        }.joined(separator: " · ")
        let dragging = reorder?.source == index
        return segmentLabel(selected: selected, frameWidth: frame.width,
                             images: images, paired: segment.rows == 2)
            .frame(height: frame.height)
            .offset(x: frame.minX)
            .contentShape(Capsule())
            .onTapGesture { onSelect(index) }
            .gesture(
                LongPressGesture(minimumDuration: 0.22)
                    .sequenced(before: DragGesture(minimumDistance: 8, coordinateSpace: .named("canvasMinimapBar")))
                    .onChanged { value in
                        guard case .second(true, .some(let drag)) = value else { return }
                        let fraction = drag.location.x / max(1, size.width)
                        if let target = CanvasMinimap.reorderTarget(at: fraction, segments: model.segments) {
                            reorder = (source: index, target: target)
                        }
                    }
                    .onEnded { _ in
                        if let current = reorder, current.target != current.source {
                            onMove(current.source, current.target)
                        }
                        reorder = nil
                    }
            )
            .opacity(dragging ? 0.55 : 1)
            .scaleEffect(dragging ? 0.9 : 1)
            .help(names + " · " + localizedString("Drag to reorder columns"))
            .accessibilityLabel(Text(names))
            .accessibilityValue(Text("\(index + 1)"))
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func segmentLabel(selected: Bool, frameWidth: CGFloat,
                              images: [NSImage], paired: Bool) -> some View {
        HStack(spacing: 2) {
            if images.isEmpty {
                Image(systemName: "app").font(.system(size: 12))
            } else {
                ForEach(Array(images.prefix(frameWidth > 30 ? 2 : 1).enumerated()), id: \.offset) { pair in
                    iconView(pair.element)
                }
            }
            if paired && images.count < 2 && frameWidth > 30 {
                badgeText(selected: selected)
            }
        }
        .frame(width: frameWidth)
        .frame(maxHeight: .infinity)
        .clipped()
        .background(segmentBackground(selected: selected))
        .overlay(segmentBorder(selected: selected))
        .contentShape(Capsule())
    }

    private func iconView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 12, height: 12)
    }

    private func badgeText(selected: Bool) -> some View {
        Text("2")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
    }

    private func segmentBackground(selected: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.07))
    }

    private func segmentBorder(selected: Bool) -> some View {
        Capsule()
            .strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
    }
}
