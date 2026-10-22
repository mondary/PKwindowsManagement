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

        // The SwiftUI dummy Settings scene must not be mistaken for the real
        // custom window (which owns the "settings" identifier).
        let fake = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 150),
                            styleMask: [.titled], backing: .buffered, defer: true)
        fake.title = "PKwindowsManagement Settings"
        assert(SettingsWindowController.isSwiftUISettingsArtifact(fake))
        let real = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 150),
                            styleMask: [.titled], backing: .buffered, defer: true)
        real.title = "PKwindowsManagement"
        real.identifier = NSUserInterfaceItemIdentifier("settings")
        assert(!SettingsWindowController.isSwiftUISettingsArtifact(real))

        print("Settings window: retained after 10 closes and recreated when missing; SwiftUI artifact detected")
    }
}
