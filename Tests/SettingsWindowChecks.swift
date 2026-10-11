import AppKit

@main
enum SettingsWindowChecks {
    static func main() {
        _ = NSApplication.shared
        let controller = SettingsWindowController.shared
        var creations = 0
        controller.makeContent = {
            creations += 1
            let content = NSViewController()
            content.view = NSView(frame: .zero)
            return content
        }
        // Exercise AppKit's real close/reopen ownership without showing a
        // window, activating this process or disturbing the user's desktop.
        controller.prepareWindow()
        guard let original = controller.window else { fatalError("Settings window was not created") }
        assert(!original.isVisible)
        assert(original.identifier?.rawValue == "settings")
        for _ in 0..<10 {
            original.close()
            controller.prepareWindow()
            assert(controller.window === original)
            assert(controller.window?.contentViewController != nil)
        }
        assert(creations == 1)
        // A missing window is recreated without a LaunchServices reopen event.
        controller.window = nil
        controller.prepareWindow()
        assert(controller.window != nil)
        assert(controller.window !== original)
        assert(creations == 2)
        print("Settings window: retained after 10 closes and recreated when missing")
    }
}
