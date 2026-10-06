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
    /// Tile gap in preview points (the real layout uses RoomTiler.gap).
    private let previewGap: CGFloat = 4

    /// `.auto` must resolve against a real screen, not the tiny preview, or it
    /// would always degrade to Stack here.
    private var resolvedKind: RoomLayoutKind {
        guard kind == .auto else { return kind }
        let size = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let area = CGRect(origin: .zero, size: size)
        return RoomTiler.autoKind(count: windows.count, in: area)
    }

    var body: some View {
        GeometryReader { geo in
            let area = CGRect(origin: .zero, size: geo.size)
            let frames = RoomTiler.frames(count: windows.count, kind: resolvedKind, in: area, gap: previewGap)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
                    )
                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    tile(window: windows[index], index: index, frame: frame)
                }
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: kind)
    }

    @ViewBuilder
    private func tile(window: RoomWindow, index: Int, frame: CGRect) -> some View {
        if frame.width >= 12, frame.height >= 9 {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index == 0 ? Color.accentColor.opacity(0.32) : Color.primary.opacity(0.10))
                if frame.width >= 24, frame.height >= 18 {
                    Image(nsImage: RoomIconCache.icon(for: window))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: min(18, frame.width - 8),
                            height: min(18, frame.height - 8)
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.8)
            )
            .overlay(alignment: .bottomTrailing) {
                if frame.width >= 20, frame.height >= 14 {
                    Text("\(index + 1)")
                        .font(.system(size: 7, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.55))
                        .padding(2)
                }
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .help(window.title.isEmpty ? window.appName : "\(window.appName) — \(window.title)")
        }
    }
}
