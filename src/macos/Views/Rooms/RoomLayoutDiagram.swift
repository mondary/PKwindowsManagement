import AppKit
import SwiftUI

/// App icons for rooms, cached by bundle identifier.
enum RoomIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(bundleID: String, name: String) -> NSImage {
        if let cached = cache.object(forKey: bundleID as NSString) { return cached }
        var image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: name) ?? NSImage()
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let candidate = NSWorkspace.shared.icon(forFile: url.path)
            candidate.size = NSSize(width: 32, height: 32)
            image = candidate
        }
        cache.setObject(image, forKey: bundleID as NSString)
        return image
    }

    static func icon(for window: RoomWindow) -> NSImage {
        icon(bundleID: window.bundleID, name: window.appName)
    }
}

/// Live miniature of a room's tiling composition: one tile per window, its
/// app icon and its number (1 is the main spot), sized by the same geometry
/// engine that arranges the real screen — so the preview shows what the room
/// will do. Animates when the layout changes.
struct RoomLayoutDiagram: View {
    let windows: [RoomWindow]
    let kind: RoomLayoutKind
    var focusedWindowIndex = 0
    var useSavedFrames = false
    /// Tile gap in preview points (the real layout uses RoomTiler.gap).
    private let previewGap: CGFloat = 4

    init(windows: [RoomWindow], kind: RoomLayoutKind, focusedWindowIndex: Int = 0, useSavedFrames: Bool = false) {
        self.windows = windows
        self.kind = kind
        self.focusedWindowIndex = focusedWindowIndex
        self.useSavedFrames = useSavedFrames
    }

    init(room: Room) {
        self.windows = room.windows
        self.kind = room.layout
        self.focusedWindowIndex = room.focusedWindowIndex
        self.useSavedFrames = room.useSavedFrames && room.hasSavedFrames
    }

    private var showingSavedFrames: Bool {
        useSavedFrames && windows.contains { $0.savedFrame != nil }
    }

    /// `.auto` must resolve against a real screen, not the tiny preview, or it
    /// would always degrade to Stack here.
    private var resolvedKind: RoomLayoutKind {
        guard kind == .auto else { return kind }
        let size = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let area = CGRect(origin: .zero, size: size)
        return RoomTiler.autoKind(count: windows.count, in: area)
    }

    private func diagramFrames(in area: CGRect) -> [CGRect] {
        guard !windows.isEmpty else { return [] }
        let fallback = RoomTiler.frames(count: windows.count, kind: resolvedKind, in: area, gap: previewGap)
        guard showingSavedFrames else { return fallback }
        let insetArea = area.insetBy(dx: previewGap, dy: previewGap)
        return windows.indices.map { index in
            if let saved = windows[index].savedFrame {
                return saved.rect(in: insetArea, minimumSize: CGSize(width: 22, height: 16))
            }
            return fallback.indices.contains(index) ? fallback[index] : insetArea
        }
    }

    var body: some View {
        GeometryReader { geo in
            let area = CGRect(origin: .zero, size: geo.size)
            let frames = diagramFrames(in: area)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(showingSavedFrames ? 0.12 : 0.07),
                                Color.primary.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    if showingSavedFrames || resolvedKind != .monocle || index == max(0, min(focusedWindowIndex, windows.count - 1)) {
                        tile(window: windows[index], index: index, frame: frame)
                    }
                }
                if !showingSavedFrames && resolvedKind == .monocle && windows.count > 1 {
                    HStack(spacing: 3) {
                        ForEach(windows.indices, id: \.self) { index in
                            Circle()
                                .fill(index == focusedWindowIndex ? Color.accentColor : Color.secondary.opacity(0.5))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .padding(5)
                    .background(.regularMaterial, in: Capsule())
                    .padding(7)
                }
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: kind)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: useSavedFrames)
    }

    @ViewBuilder
    private func tile(window: RoomWindow, index: Int, frame: CGRect) -> some View {
        if frame.width >= 12, frame.height >= 9 {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        index == 0
                            ? Color.accentColor.opacity(0.30)
                            : Color(nsColor: .controlBackgroundColor).opacity(0.88)
                    )
                if frame.width >= 22, frame.height >= 16 {
                    Image(nsImage: RoomIconCache.icon(for: window))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: min(20, frame.width - 7),
                            height: min(20, frame.height - 7)
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(index == 0 ? Color.accentColor.opacity(0.75) : Color.primary.opacity(0.20), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                if frame.width >= 20, frame.height >= 14 {
                    Text("\(index + 1)")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.65))
                        .padding(2.5)
                }
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .help(window.title.isEmpty ? window.appName : "\(window.appName) — \(window.title)")
        }
    }
}
