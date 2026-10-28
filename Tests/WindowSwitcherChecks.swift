import Foundation
import CoreGraphics

@main
enum WindowSwitcherChecks {
    static func main() {
        // Command/Shift do not change Return's meaning: the controller checks
        // confirmation before its held-Command text/shortcut branch.
        for keyCode: UInt16 in [36, 76] {
            precondition(WindowSwitcherState.confirmsWindowSelection(keyCode: keyCode, control: false, option: false))
            precondition(!WindowSwitcherState.confirmsWindowSelection(keyCode: keyCode, control: true, option: false))
            precondition(!WindowSwitcherState.confirmsWindowSelection(keyCode: keyCode, control: false, option: true))
        }
        for keyCode: UInt16 in [48, 53, 49, 0, 125] {
            precondition(!WindowSwitcherState.confirmsWindowSelection(keyCode: keyCode, control: false, option: false))
        }

        // Dedicated app section: regular apps (Dock) and
        // menu-bar apps are listed; prohibited daemons and protected system
        // agents never are, so the picker cannot quit macOS chrome.
        precondition(WindowSwitcherState.isListedProcess(activationPolicy: 0, bundleIdentifier: "com.example.editor"))
        precondition(WindowSwitcherState.isListedProcess(activationPolicy: 1, bundleIdentifier: "com.example.agent"))
        precondition(!WindowSwitcherState.isListedProcess(activationPolicy: 1, bundleIdentifier: nil))
        precondition(!WindowSwitcherState.isListedProcess(activationPolicy: 2, bundleIdentifier: "com.example.daemon"))
        precondition(!WindowSwitcherState.isListedProcess(activationPolicy: 1, bundleIdentifier: "com.apple.controlcenter"))
        precondition(!WindowSwitcherState.isListedProcess(activationPolicy: 0, bundleIdentifier: "com.apple.dock"))
        precondition(WindowSwitcherState.processKind(activationPolicy: 0) == .dockApp)
        precondition(WindowSwitcherState.processKind(activationPolicy: 1) == .menuBarApp)
        precondition(WindowSwitcherState.processKind(activationPolicy: 2) == nil)

        // Applications, not Activity Monitor: real menu-bar apps survive,
        // embedded LoginItems/helpers and Apple's accessory agents do not.
        typealias AppIdentity = WindowSwitcherState.ApplicationIdentity
        func app(_ pid: Int32, _ policy: Int, _ id: String?, _ path: String?) -> AppIdentity {
            AppIdentity(pid: pid, activationPolicy: policy, bundleIdentifier: id, bundlePath: path)
        }
        let mini = app(1, 0, "at.obdev.littlesnitchmini", "/Applications/Little Snitch Mini.app")
        let helper = app(2, 1, "at.obdev.littlesnitchmini.helper",
                         "/Applications/Little Snitch Mini.app/Contents/Library/LoginItems/Little Snitch Mini Helper.app")
        let monitor = app(3, 1, "app.monitorcontrol.MonitorControl", "/Applications/MonitorControl.app")
        let homebrew = app(4, 0, "sh.brew.app", "/Applications/Homebrew.app")
        let finder = app(5, 0, "com.apple.finder", "/System/Library/CoreServices/Finder.app")
        let preview = app(6, 0, "com.apple.Preview", "/System/Applications/Preview.app")
        let realApps = [mini, monitor, homebrew, finder, preview]
        let internals = [
            helper,
            app(7, 1, "com.apple.AccessibilityUIServer", "/System/Library/CoreServices/AccessibilityUIServer.app"),
            app(8, 1, "com.apple.campo", "/System/Applications/Siri AI.app"),
            app(9, 1, "com.apple.Siri", "/System/Library/CoreServices/Siri.app"),
            app(10, 1, "com.apple.wifi.WiFiAgent", "/System/Library/CoreServices/WiFiAgent.app"),
            app(11, 1, "com.apple.AirPlayUIAgent", "/System/Library/CoreServices/AirPlayUIAgent.app"),
            app(12, 1, "com.apple.controlcenter", "/System/Library/CoreServices/ControlCenter.app"),
            app(13, 1, "com.google.Chrome.helper", "/Applications/Google Chrome.app/Contents/Frameworks/Helper.app"),
            app(14, 1, "com.apple.WebKit.Networking", "/System/Library/Frameworks/WebKit.framework/XPCServices/Networking.xpc"),
            app(15, 1, "com.apple.python3", "/Library/Developer/Python.framework/Resources/Python.app"),
            app(16, 1, nil, nil),
            app(17, 2, "com.example.background", "/Applications/Background.app"),
            app(18, 0, "com.example.helper", "/Applications/Example Helper.app"),
            app(19, 0, "org.example.child", "/Applications/Product.app/Contents/MacOS/Child.app"),
            app(0, 0, "com.example.kernel", "/Applications/Kernel.app")
        ]
        precondition(WindowSwitcherState.listedApplications(realApps + internals).map(\.pid) == [1, 3, 4, 5, 6])
        precondition(WindowSwitcherState.listedApplications([helper]).isEmpty)
        let sameProductOtherProcess = app(20, 1, mini.bundleIdentifier, mini.bundlePath)
        precondition(WindowSwitcherState.listedApplications([sameProductOtherProcess, mini, monitor]).map(\.pid) == [1, 3])
        precondition(WindowSwitcherState.listedApplications([mini, sameProductOtherProcess, mini]).map(\.pid) == [1])
        // Exact bundle identity only: companion products are NOT one app.
        let companion = app(21, 0, "at.obdev.littlesnitch", "/Applications/Little Snitch.app")
        precondition(WindowSwitcherState.listedApplications([mini, companion]).map(\.pid) == [1, 21])
        precondition(WindowSwitcherState.listedApplications([
            app(22, 1, "com.pk.monitor", "/Users/test/Projects/Monitor.app"),
            app(23, 0, nil, "/Users/test/Dev/Unsigned.app")
        ]).map(\.pid) == [22, 23])

        // Steam: NSWorkspace reports pid -1 and a Steam.AppBundle launcher
        // path without an .app suffix. It must stay listed (Dock-visible app)
        // while its embedded helper stays hidden — and two pid-less apps must
        // never collapse into one entry.
        let steam = app(-1, 0, "com.valvesoftware.steam",
                        "/Users/test/Library/Application Support/Steam/Steam.AppBundle/Steam")
        let steamHelper = app(24, 1, "com.valvesoftware.steam.helper",
                              "/Users/test/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/Frameworks/Steam Helper.app")
        let otherPidless = app(-1, 0, "com.example.pwa",
                               "/Users/test/Applications/Weird PWA/Weird.AppBundle/Run")
        let steamListed = WindowSwitcherState.listedApplications([steam, steamHelper, otherPidless])
        precondition(steamListed.count == 2)
        precondition(Set(steamListed.compactMap(\.bundleIdentifier)) == ["com.valvesoftware.steam", "com.example.pwa"])
        precondition(steamListed.allSatisfy { $0.pid != 0 })

        // The window inventory and the process sections overlap by design: a
        // regular app without listed windows appears in both with the same
        // PID. Dev 108 crashed on ⌘Tab by building the icon table with
        // Dictionary(uniqueKeysWithValues:); duplicated PIDs must dedupe
        // silently, keeping the first value.
        let iconTable = WindowSwitcherState.uniqueValuesByPID([
            (pid: 100, value: "grid"), (pid: 101, value: "dock"), (pid: 100, value: "grid-again")
        ])
        precondition(iconTable.count == 2)
        precondition(iconTable[100] == "grid" && iconTable[101] == "dock")
        precondition(WindowSwitcherState.uniqueValuesByPID([(pid: 1, value: 0)] as [(pid: Int32, value: Int)]).count == 1)

        // Only regular apps own the windows the picker should show. Menu-bar
        // apps, widget hosts and system chrome are accessory/prohibited apps,
        // even when they expose HUD or desktop windows.
        precondition(WindowSwitcherState.includesApplication(activationPolicy: 0, bundleIdentifier: "com.apple.finder"))
        precondition(WindowSwitcherState.includesApplication(activationPolicy: 0, bundleIdentifier: nil))
        precondition(!WindowSwitcherState.includesApplication(activationPolicy: 1, bundleIdentifier: "com.foo.menu-bar"))
        precondition(!WindowSwitcherState.includesApplication(activationPolicy: 2, bundleIdentifier: "com.foo.background"))
        precondition(!WindowSwitcherState.includesApplication(activationPolicy: 0, bundleIdentifier: "com.apple.notificationcenterui"))
        precondition(!WindowSwitcherState.includesApplication(activationPolicy: 0, bundleIdentifier: "com.apple.controlcenter"))

        let items: [WindowSwitcherItem] = (0..<64).map { (index: Int) -> WindowSwitcherItem in
            let id = WindowSwitcherID(pid: Int32(index / 16 + 100), windowID: UInt32(index + 1))
            let appName = index < 32 ? "Éditeur" : "Safari"
            let title = index == 0 ? "" : "Projet \(index)"
            return WindowSwitcherItem(id: id, appName: appName, title: title, isMinimized: index == 3,
                isHidden: index == 4, isFullScreen: index == 5, isOnScreen: index < 32)
        }
        precondition(items[0].displayTitle == "Éditeur")
        precondition(WindowSwitcherState.filtered(items, query: "  \n ").count == 64)
        precondition(WindowSwitcherState.filtered(items, query: "editeur PROJET 12").map(\.id) == [items[12].id])
        precondition(WindowSwitcherState.filtered(items, query: "Safari\tprojet 63").map(\.id) == [items[63].id])
        precondition(WindowSwitcherState.filtered(items, query: "missing").isEmpty)
        // Distinct windows may have identical titles; filtering must not deduplicate them.
        let duplicate = WindowSwitcherItem(id: .init(pid: 999, windowID: 1), appName: "Éditeur", title: "",
            isMinimized: false, isHidden: false, isFullScreen: false, isOnScreen: true)
        precondition(WindowSwitcherState.filtered([items[0], duplicate], query: "editeur").count == 2)
        precondition(Set([items[0].id, duplicate.id]).count == 2)

        precondition(WindowSwitcherState.initialSelection(in: items, focused: items[0].id) == items[1].id)
        precondition(WindowSwitcherState.initialSelection(in: [items[0]], focused: items[0].id) == items[0].id)
        precondition(WindowSwitcherState.initialSelection(in: [WindowSwitcherItem](), focused: nil) == nil)
        precondition(WindowSwitcherState.initialSelection(in: items, focused: nil) == items[0].id)

        // Process rows follow the window grid in the single keyboard stream,
        // and the shared filter still matches their app name.
        let process = WindowSwitcherItem(id: .init(pid: 777, windowID: 0), appName: "Agent",
            title: "", isMinimized: false, isHidden: false, isFullScreen: false, isOnScreen: false,
            kind: .menuBarApp)
        let roomIDs = ["work", "personal"]
        let targets = WindowSwitcherState.navigationTargets(
            windows: [items[0], items[1]], apps: [process], roomIDs: roomIDs)
        precondition(targets == [.item(items[0].id), .item(items[1].id), .item(process.id),
                                 .room("work"), .room("personal")])
        precondition(WindowSwitcherState.initialSelection(in: targets, focused: items[0].id) == .item(items[1].id))
        precondition(WindowSwitcherState.commandTabSelection(in: targets, focused: items[0].id, offset: 0) == .item(items[1].id))
        precondition(WindowSwitcherState.commandTabSelection(in: targets, focused: items[0].id, offset: 1) == .item(process.id))
        precondition(WindowSwitcherState.commandTabSelection(in: targets, focused: items[0].id, offset: 2) == .room("work"))
        precondition(WindowSwitcherState.commandTabSelection(in: targets, focused: items[0].id, offset: -1) == .room("personal"))
        precondition(WindowSwitcherState.moved(in: targets, from: .item(process.id), by: 1, wrapping: false) == .room("work"))
        precondition(WindowSwitcherState.selection(in: targets, keeping: .room("personal")) == .room("personal"))
        precondition(WindowSwitcherState.selectionAfterClosing(items[0].id, in: targets, selected: .room("work")) == .room("work"))
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: process.id.pid, in: targets,
            selected: .item(process.id)) == .room("work"))
        // The regular-app window list and the Dock-app list intentionally
        // overlap. Icon cache construction must safely keep the first entry.
        precondition(WindowSwitcherState.uniqueValuesByPID([
            (pid: 100, value: "window-list"), (pid: 100, value: "app-list"), (pid: 200, value: "menu-bar")
        ]) == [100: "window-list", 200: "menu-bar"])
        precondition(process.isProcess)
        precondition(!items[0].isProcess)
        precondition(WindowSwitcherState.navigationItems(windows: [items[0]], processes: [process]) == [items[0], process])
        precondition(WindowSwitcherState.navigationItems(windows: [], processes: [process]) == [process])
        precondition(WindowSwitcherState.filtered([process], query: "agent").map(\.id) == [process.id])
        // Sticky ⌘Tab keeps the picker only while a filter is typed; a plain
        // release must still switch windows.
        precondition(!WindowSwitcherState.defersCommandTabCommit(sticky: false, query: "safari"))
        precondition(!WindowSwitcherState.defersCommandTabCommit(sticky: true, query: ""))
        precondition(!WindowSwitcherState.defersCommandTabCommit(sticky: true, query: "   \n"))
        precondition(WindowSwitcherState.defersCommandTabCommit(sticky: true, query: "safari"))
        // Hold-⌘ starts on the previous window, ⇧⌘⇥ on the least recent one,
        // and offsets keep accumulating while the inventory is loading.
        precondition(WindowSwitcherState.commandTabSelection(in: items, focused: items[0].id, offset: 0) == items[1].id)
        precondition(WindowSwitcherState.commandTabSelection(in: items, focused: items[0].id, offset: 1) == items[2].id)
        precondition(WindowSwitcherState.commandTabSelection(in: items, focused: items[0].id, offset: 2) == items[3].id)
        precondition(WindowSwitcherState.commandTabSelection(in: items, focused: items[0].id, offset: -1) == items[63].id)
        precondition(WindowSwitcherState.commandTabSelection(in: items, focused: items[0].id, offset: -2) == items[62].id)
        precondition(WindowSwitcherState.commandTabSelection(in: items, focused: items[0].id, offset: -64) == items[0].id)
        precondition(WindowSwitcherState.commandTabSelection(in: items, focused: nil, offset: 0) == items[0].id)
        precondition(WindowSwitcherState.commandTabSelection(in: items, focused: nil, offset: 1) == items[1].id)
        precondition(WindowSwitcherState.commandTabSelection(in: [items[0]], focused: items[0].id, offset: -1) == items[0].id)
        precondition(WindowSwitcherState.commandTabSelection(in: [WindowSwitcherItem](), focused: nil, offset: -1) == nil)
        // Quitting an app removes all of its windows at once.
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: items, selected: items[0].id) == items[16].id)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: items, selected: items[4].id) == items[16].id)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: items, selected: items[40].id) == items[40].id)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 103, in: items, selected: items[63].id) == items[47].id)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: [items[0]], selected: items[0].id) == nil)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: [WindowSwitcherItem](), selected: nil) == nil)
        let filtered = WindowSwitcherState.filtered(items, query: "safari")
        for index in filtered.indices {
            let selected = filtered[index].id
            let next = WindowSwitcherState.selectionAfterClosing(selected, in: filtered, selected: selected)
            let expected = filtered[index == filtered.count - 1 ? index - 1 : index + 1].id
            precondition(next == expected)
        }
        // Closing a different card must preserve keyboard selection and filtered order.
        precondition(WindowSwitcherState.selectionAfterClosing(items[40].id, in: filtered, selected: items[50].id) == items[50].id)
        precondition(WindowSwitcherState.selectionAfterClosing(items[0].id, in: filtered, selected: items[50].id) == items[50].id)
        precondition(WindowSwitcherState.selectionAfterClosing(items[0].id, in: [items[0]], selected: items[0].id) == nil)
        precondition(WindowSwitcherState.selectionAfterClosing(items[0].id, in: [WindowSwitcherItem](), selected: nil) == nil)
        precondition(WindowSwitcherState.selection(in: filtered, keeping: items[40].id) == items[40].id)
        precondition(WindowSwitcherState.selection(in: filtered, keeping: items[2].id) == items[32].id)
        precondition(WindowSwitcherState.selection(in: [], keeping: items[2].id) == nil)
        // Closing the selected window during refresh chooses a live window.
        precondition(WindowSwitcherState.selection(in: Array(items.dropFirst()), keeping: items[0].id) == items[1].id)

        for count in [1, 2, 3, 8, 14, 24, 64] {
            let windows = Array(items.prefix(count))
            precondition(WindowSwitcherState.moved(in: windows, from: windows.last!.id, by: 1, wrapping: true) == windows.first!.id)
            precondition(WindowSwitcherState.moved(in: windows, from: windows.first!.id, by: -1, wrapping: true) == windows.last!.id)
            for index in windows.indices {
                for columns in 1...3 {
                    let down = WindowSwitcherState.moved(in: windows, from: windows[index].id, by: columns, wrapping: false)
                    precondition(down == windows[min(index + columns, count - 1)].id)
                    let up = WindowSwitcherState.moved(in: windows, from: windows[index].id, by: -columns, wrapping: false)
                    precondition(up == windows[max(index - columns, 0)].id)
                }
            }
        }
        precondition(WindowSwitcherState.moved(in: [WindowSwitcherItem](), from: nil, by: 1, wrapping: true) == nil)
        precondition(WindowSwitcherState.moved(in: items, from: nil, by: -1, wrapping: true) == items[0].id)

        // Extreme aspect ratios, Retina windows and unavailable geometry stay bounded.
        for size in [CGSize(width: 3440, height: 1440), CGSize(width: 100, height: 9000),
                     CGSize(width: 1, height: 1), .zero, CGSize(width: -1, height: 2),
                     CGSize(width: CGFloat.infinity, height: 50)] {
            let result = WindowSwitcherState.thumbnailSize(for: size)
            precondition(result.width >= 1 && result.width <= 640)
            precondition(result.height >= 1 && result.height <= 400)
        }
        let portrait = WindowSwitcherState.thumbnailSize(for: CGSize(width: 1000, height: 2000))
        precondition(portrait == CGSize(width: 200, height: 400))
        // Every card has the same height inside one layout; only the column
        // count changes it.
        precondition(WindowSwitcherState.cardHeight(forWidth: 1120, columns: 4) == 210)
        precondition(WindowSwitcherState.cardHeight(forWidth: 740, columns: 3) == 190)
        precondition(WindowSwitcherState.cardHeight(forWidth: 500, columns: 2) == 190)
        precondition(WindowSwitcherState.cardHeight(forWidth: 400, columns: 1) == 210)
        print("Window switcher checks passed: search/accents, identity, 1–64 windows, filtering/closure selection, grid navigation, equal card heights and bounded thumbnails")
    }
}
