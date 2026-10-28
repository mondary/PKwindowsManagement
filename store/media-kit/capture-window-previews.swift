import AppKit
import SwiftUI

/// Isolated native rendering: no app delegate, event taps, AX or capture calls.
@main
struct WindowPreviewCapture {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let roomsURL = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for language in ["fr", "en"] {
            UserDefaults.standard.setVolatileDomain(["app-language": language], forName: UserDefaults.argumentDomain)
            for dark in [false, true] {
                NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                let model = fixtureModel(roomsURL: roomsURL)
                try render(model, width: 880, language: language, dark: dark,
                           name: "window-previews", output: output)
            }
            NSApp.appearance = NSAppearance(named: .aqua)
            let narrow = fixtureModel(roomsURL: roomsURL)
            narrow.columns = 2
            try render(narrow, width: 520, language: language, dark: false, name: "window-previews-narrow", output: output)
            let creation = fixtureModel(roomsURL: roomsURL)
            creation.isCreatingRoom = true
            creation.roomName = "Studio"
            creation.creationLayout = .grid
            creation.roomPicks = Array(creation.items.prefix(3).map(\.id))
            creation.selectedID = creation.roomPicks.first
            try render(creation, width: 880, language: language, dark: false, name: "room-creation", output: output)
            let denied = fixtureModel(roomsURL: roomsURL)
            denied.previewsGranted = false
            denied.images = [:]
            try render(denied, width: 880, language: language, dark: false, name: "window-previews-permission", output: output)
        }
        print("Rendered picker fixtures in FR/EN, light/dark, narrow, room creation and permission states; no user windows accessed")
    }

    @MainActor private static func fixtureModel(roomsURL: URL) -> WindowSwitcherModel {
        let roomStore = RoomStore(url: roomsURL)
        let model = WindowSwitcherModel(roomStore: roomStore)
        model.accessibilityGranted = true
        model.previewsGranted = true
        let names = ["Éditeur", "Safari", "Finder", "Terminal", "Notes", "Safari"]
        let titles = ["Projet Atlas — index.swift", "Documentation — ScreenCaptureKit", "Documents du projet",
                      "atlas — swift build", "Idées pour la prochaine version", "Recherche — interfaces macOS"]
        let symbols = ["curlybraces.square.fill", "safari.fill", "folder.fill", "terminal.fill", "note.text", "safari.fill"]
        var items: [WindowSwitcherItem] = []
        for index in 0..<6 {
            let id = WindowSwitcherID(pid: Int32(index + 100), windowID: UInt32(index + 1))
            let item = WindowSwitcherItem(id: id, appName: names[index], title: titles[index],
                isMinimized: index == 4, isHidden: false, isFullScreen: false, isOnScreen: index != 5)
            items.append(item)
            model.icons[id.pid] = NSImage(systemSymbolName: symbols[index], accessibilityDescription: nil)
            if index != 4 { model.images[id] = document(title: titles[index], index: index) }
        }
        model.items = items
        model.completedPreviews = Set(items.map(\.id))
        model.selectedID = items[1].id
        let runningApps = [
            WindowSwitcherItem(id: .init(pid: 201, windowID: 0), appName: "Calendar", title: "",
                isMinimized: false, isHidden: false, isFullScreen: false, isOnScreen: false, kind: .dockApp),
            WindowSwitcherItem(id: .init(pid: 202, windowID: 0), appName: "Music", title: "",
                isMinimized: false, isHidden: false, isFullScreen: false, isOnScreen: false, kind: .dockApp),
            WindowSwitcherItem(id: .init(pid: 203, windowID: 0), appName: "PKmonitor", title: "",
                isMinimized: false, isHidden: false, isFullScreen: false, isOnScreen: false, kind: .menuBarApp)
        ]
        model.processItems = runningApps
        model.icons[201] = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
        model.icons[202] = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        model.icons[203] = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: nil)
        roomStore.upsert(Room(id: "studio", name: "Studio", windows: [
            RoomWindow(bundleID: "com.apple.finder", appName: "Finder", title: "Project files", windowID: 1),
            RoomWindow(bundleID: "com.apple.Safari", appName: "Safari", title: "Research", windowID: 2),
            RoomWindow(bundleID: "com.apple.Terminal", appName: "Terminal", title: "Build", windowID: 3)
        ], layout: .columns))
        roomStore.upsert(Room(id: "review", name: "Review", windows: [
            RoomWindow(bundleID: "com.apple.Notes", appName: "Notes", title: "Review notes", windowID: 4),
            RoomWindow(bundleID: "com.apple.mail", appName: "Mail", title: "Feedback", windowID: 5)
        ], layout: .grid))
        return model
    }

    /// Illustrative document fixtures; these are not screenshots of other apps.
    @MainActor private static func document(title: String, index: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 480, height: 300))
        image.lockFocus()
        let dark = index == 0 || index == 3
        (dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.97, alpha: 1)).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 480, height: 300)).fill()
        let color = NSColor(calibratedWhite: dark ? 1 : 0, alpha: 1)
        (title as NSString).draw(at: NSPoint(x: 24, y: 205), withAttributes: [
            .font: NSFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: color
        ])
        for line in 0..<7 {
            color.withAlphaComponent(0.1 + Double(line % 3) * 0.05).setFill()
            NSBezierPath(roundedRect: NSRect(x: 24, y: 220 - line * 26, width: 220 + (line % 3) * 68, height: 8),
                         xRadius: 3, yRadius: 3).fill()
        }
        image.unlockFocus()
        return image
    }

    @MainActor private static func render(_ model: WindowSwitcherModel, width: CGFloat, language: String,
                                          dark: Bool, name: String, output: URL) throws {
        let height: CGFloat = 1000
        let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView:
            WindowSwitcherView(model: model, roomStore: model.roomStore, onActivate: { _ in }, onClose: {})
                .environment(\.locale, Locale(identifier: language))
                .environment(\.colorScheme, dark ? .dark : .light))
        hosting.sizingOptions = []
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        window.setContentSize(NSSize(width: width, height: height))
        window.orderBack(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        let content = window.contentView!
        content.layoutSubtreeIfNeeded()
        let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
        content.cacheDisplay(in: content.bounds, to: bitmap)
        let suffix = dark ? "dark" : "light"
        try bitmap.representation(using: .png, properties: [:])!.write(
            to: output.appendingPathComponent("\(name)-\(language)-\(suffix).png"))
        window.orderOut(nil)
    }
}
