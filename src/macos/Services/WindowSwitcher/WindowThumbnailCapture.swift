import AppKit
import ScreenCaptureKit

/// One capture session per picker opening. No stream or on-disk image cache.
actor WindowThumbnailCapture {
    private var content: SCShareableContent?
    private var didRequestContent = false

    func image(for id: WindowSwitcherID) async -> CGImage? {
        guard !Task.isCancelled, CGPreflightScreenCaptureAccess() else { return nil }
        if #available(macOS 14.0, *) {
            if !didRequestContent {
                didRequestContent = true
                content = await WindowCaptureRequest<SCShareableContent>.perform { complete in
                    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { content, _ in
                        complete(content)
                    }
                }
            }
            guard !Task.isCancelled,
                  let window = content?.windows.first(where: {
                      $0.windowID == id.windowID && $0.owningApplication?.processID == id.pid
                  }) else { return nil }
            let config = SCStreamConfiguration()
            let size = WindowSwitcherState.thumbnailSize(for: window.frame.size)
            config.width = Int(size.width)
            config.height = Int(size.height)
            config.showsCursor = false
            config.scalesToFit = true
            config.preservesAspectRatio = true
            config.ignoreShadowsSingleWindow = true
            let image = await WindowCaptureRequest<CGImage>.perform { complete in
                SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window),
                                                 configuration: config) { image, _ in complete(image) }
            }
            return Task.isCancelled ? nil : image
        } else {
            return legacyImage(for: id.windowID)
        }
    }

    @available(macOS, introduced: 13.0, obsoleted: 14.0)
    private func legacyImage(for id: CGWindowID) -> CGImage? {
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) else {
            return nil
        }
        let size = WindowSwitcherState.thumbnailSize(for: CGSize(width: image.width, height: image.height))
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}
