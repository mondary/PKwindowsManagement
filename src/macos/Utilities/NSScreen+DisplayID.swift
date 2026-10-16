import AppKit
import CoreGraphics

extension NSScreen {
    var launchpadDisplayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    static func screen(forDisplayID id: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.launchpadDisplayID == id }
    }
}
