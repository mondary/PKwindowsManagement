import Foundation

@main
enum ExposeMinimizedChecks {
    static func item(_ id: UInt32, minimized: Bool) -> WindowSwitcherItem {
        WindowSwitcherItem(id: .init(pid: 10, windowID: id), appName: "Chrome",
            title: "W\(id)", isMinimized: minimized, isHidden: false,
            isFullScreen: false, isOnScreen: !minimized, frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    static func main() throws {
        let items = [item(1, minimized: false), item(2, minimized: true),
                     item(3, minimized: false), item(4, minimized: true)]
        // Normal and dimmed keep every window, in order.
        for display in [ExposeMinimizedDisplay.normal, .dimmed] {
            let kept = WindowSwitcherState.exposeItems(items, display: display)
            precondition(kept.map(\.id.windowID) == [1, 2, 3, 4])
        }
        // Hidden lists only visible windows.
        precondition(WindowSwitcherState.exposeItems(items, display: .hidden).map(\.id.windowID) == [1, 3])
        // Search composes first, minimized rule last.
        let filtered = WindowSwitcherState.filtered(items, query: "W")
        precondition(filtered.count == 4)
        precondition(WindowSwitcherState.exposeItems(filtered, display: .hidden).count == 2)
        precondition(WindowSwitcherState.exposeItems(
            WindowSwitcherState.filtered(items, query: "W2"), display: .hidden).isEmpty)
        precondition(WindowSwitcherState.exposeItems(
            WindowSwitcherState.filtered(items, query: "W2"), display: .dimmed).count == 1)
        precondition(ExposeMinimizedDisplay(rawValue: "dimmed") == .dimmed)

        // Source wiring guards (no window is focused or captured here).
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        func source(_ relative: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        }
        let model = try source("src/macos/Services/WindowSwitcher/WindowSwitcherModel.swift")
        precondition(model.contains("WindowSwitcherState.exposeItems(filteredItems"))
        // Requests come from laid-out cards, so Hidden cannot warm windows
        // excluded from the scene by the policy above.
        let controller = try source("src/macos/Services/WindowSwitcher/WindowSwitcherController.swift")
        precondition(controller.contains("for placement in scene.overview.windows"))
        precondition(controller.contains("model.requestPreview(placement.id)"))
        let view = try source("src/macos/Views/WindowSwitcher/ExposeView.swift")
        precondition(view.contains("let item = placement.item"))
        precondition(view.contains(".onAppear { model.requestPreview(item.id) }"))
        precondition(view.contains("scene.minimizedDisplay == .dimmed"))
        precondition(view.contains("Self.dimmedFrame(target)"))
        precondition(view.contains(".opacity(dimmed ? 0.5 : 1)"))
        precondition(view.contains("dimmed && scene.mode == .strip"))
        let layout = try source("src/macos/Services/WindowSwitcher/ExposeLayout.swift")
        precondition(layout.contains("placements += packShelf(minimized, in: shelf)"))
        precondition(layout.contains("bestPacking(open, in: main)"))
        precondition(layout.contains("open.isEmpty ? [] : bestPacking(open, in: main)"))
        precondition(layout.contains("placements = bestPacking(group.windows, in: grid)"))
        precondition(layout.contains("let dormantIndices = groups.indices.filter"))
        precondition(layout.contains("if !dockBand.isNull {"))
        let settingsSource = try source("src/macos/AppSettings.swift")
        precondition(settingsSource.contains("exposeMinimizedDisplay = ExposeMinimizedDisplay(rawValue:"))
        precondition(settingsSource.contains("exposeMinimizedDisplay: ExposeMinimizedDisplay?"))
        let ui = try source("src/macos/Views/Preferences/WindowSwitcherSettingsView.swift")
        precondition(ui.contains("$settings.exposeMinimizedDisplay"))

        print("Exposé minimized checks passed: hidden filters, normal/dimmed keep order, search composition, defaults, backup field, view/model/settings wiring, island shelf packing and dormant dock band")
    }
}
