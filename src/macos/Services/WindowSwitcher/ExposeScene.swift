import AppKit
import AVFoundation
import ImageIO
import Combine
import SwiftUI

/// One coordinated animation clock for the borderless overlay on every display.
/// All app groups settle on the display where Exposé was invoked; replicas on
/// other screens travel from their real positions across the display boundary.
final class ExposeScene: ObservableObject {
    struct Screen: Identifiable {
        let id: CGDirectDisplayID
        let appKitFrame: CGRect
        let frame: CGRect
        let safeTop: CGFloat
        let wallpaperURL: URL?
        let fill: NSColor
        let fitWallpaper: Bool
    }

    let screens: [Screen]
    let activeID: CGDirectDisplayID
    let activeFrame: CGRect
    let safeTop: CGFloat
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    @Published var expanded = false
    @Published var dismissing = false
    @Published private(set) var overview = ExposeLayout.Overview()
    @Published private(set) var mode: ExposeLayout.Mode
    @Published private(set) var scrollOffset: CGFloat = 0
    private let defaults: UserDefaults
    private var lastGroups: [ExposeLayout.Group] = []
    private var reservesNoticeSpace = false
    private static let modeKey = "pkwm.expose.layoutMode"
    var onModeChange: ((ExposeLayout.Mode) -> Void)?

    var availableArea: CGRect {
        let top: CGFloat = activeFrame.width < 900 ? 112 : 66
        let notice: CGFloat = reservesNoticeSpace ? 50 : 0
        return CGRect(x: activeFrame.minX + 20, y: activeFrame.minY + safeTop + top + notice,
                      width: max(1, activeFrame.width - 40),
                      height: max(1, activeFrame.height - safeTop - top - notice - (activeFrame.width < 1100 ? 92 : 60)))
    }
    @Published private(set) var wallpapers: [CGDirectDisplayID: NSImage] = [:]
    var entryDuration: TimeInterval { reduceMotion ? 0.15 : 0.38 }
    var exitDuration: TimeInterval { reduceMotion ? 0.12 : 0.28 }

    init?(screens: [NSScreen], active: NSScreen, defaults: UserDefaults = .standard) {
        let descriptions = screens.compactMap { screen -> Screen? in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
            let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
            return Screen(id: id, appKitFrame: screen.frame, frame: CGDisplayBounds(id),
                safeTop: max(screen.safeAreaInsets.top, 24),
                wallpaperURL: NSWorkspace.shared.desktopImageURL(for: screen),
                fill: options[.fillColor] as? NSColor ?? .black,
                fitWallpaper: options[.allowClipping] as? Bool == false)
        }
        guard let activeID = active.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let target = descriptions.first(where: { $0.id == activeID }) else { return nil }
        self.defaults = defaults
        self.mode = ExposeLayout.Mode(rawValue: defaults.string(forKey: Self.modeKey) ?? "") ?? .islands
        self.screens = descriptions
        self.activeID = activeID
        self.activeFrame = target.frame
        self.safeTop = target.safeTop
    }

    func update(groups: [ExposeLayout.Group], hasNotice: Bool = false) {
        lastGroups = groups
        reservesNoticeSpace = hasNotice
        let area = availableArea
        let next = mode == .islands ? ExposeLayout.overview(groups: groups, in: area)
            : ExposeLayout.strip(groups: groups, in: area)
        if next != overview { overview = next }
        scrollOffset = ExposeLayout.clampedOffset(scrollOffset, contentWidth: next.contentWidth, viewportWidth: area.width)
    }

    func setMode(_ mode: ExposeLayout.Mode) {
        guard self.mode != mode, !dismissing else { return }
        self.mode = mode
        defaults.set(mode.rawValue, forKey: Self.modeKey)
        onModeChange?(mode)
        scrollOffset = 0
        update(groups: lastGroups, hasNotice: reservesNoticeSpace)
    }

    func displayed(_ rect: CGRect) -> CGRect {
        rect.offsetBy(dx: mode == .strip ? -scrollOffset : 0, dy: 0)
    }

    func scroll(by delta: CGFloat) {
        guard mode == .strip, expanded, !dismissing, delta.isFinite else { return }
        scrollOffset = ExposeLayout.clampedOffset(scrollOffset + delta,
            contentWidth: overview.contentWidth, viewportWidth: availableArea.width)
    }

    func reveal(_ id: WindowSwitcherID?) {
        guard mode == .strip, let id, let window = overview.windows.first(where: { $0.id == id }) else { return }
        let shown = displayed(window.frame)
        if shown.minX < availableArea.minX || shown.maxX > availableArea.maxX {
            scrollOffset = ExposeLayout.clampedOffset(window.frame.midX - availableArea.midX,
                contentWidth: overview.contentWidth, viewportWidth: availableArea.width)
        }
    }

    func hitTest(_ point: CGPoint) -> WindowSwitcherID? {
        guard expanded, !dismissing else { return nil }
        return ExposeLayout.hitTest(point, in: overview, offset: mode == .strip ? scrollOffset : 0,
                                   visibleArea: availableArea)
    }

    /// Read the selected wallpaper file, not the user's screen. For aerial
    /// movies use a poster frame; never start a video stream behind the UI.
    func loadWallpapers() async {
        for screen in screens {
            guard !Task.isCancelled, wallpapers[screen.id] == nil, let url = screen.wallpaperURL else { continue }
            let image = await Task.detached(priority: .userInitiated) { () -> CGImage? in
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                       kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: 3840
                   ] as CFDictionary) { return image }
                guard ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased()) else { return nil }
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 3840, height: 2160)
                guard let cg = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
                return cg
            }.value
            guard !Task.isCancelled else { return }
            if let image { wallpapers[screen.id] = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)) }
        }
    }
}
