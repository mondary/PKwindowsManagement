import Foundation

extension Notification.Name {
    static let launchpadHotKeyDidChange = Notification.Name("launchpadHotKeyDidChange")
    static let launchpadHotCornerDidChange = Notification.Name("launchpadHotCornerDidChange")
}

final class AppRuntime {
    static let shared = AppRuntime()

    var settings: AppSettings? {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .launchpadHotKeyDidChange, object: nil)
                NotificationCenter.default.post(name: .launchpadHotCornerDidChange, object: nil)
            }
        }
    }
}
