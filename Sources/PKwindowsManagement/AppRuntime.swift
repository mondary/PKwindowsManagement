import Foundation

extension Notification.Name {
    static let launchpadHotKeyDidChange = Notification.Name("launchpadHotKeyDidChange")
}

final class AppRuntime {
    static let shared = AppRuntime()

    var settings: AppSettings? {
        didSet {
            NotificationCenter.default.post(name: .launchpadHotKeyDidChange, object: nil)
        }
    }
    var openSettings: (() -> Void)?
}
