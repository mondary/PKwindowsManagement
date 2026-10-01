import AppKit
import SwiftUI
import Vision

@main
enum StoreCapture {
    @MainActor
    static func main() throws {
        guard let identifier = Bundle.main.bundleIdentifier,
              identifier.hasPrefix("org.pk.storecapture.run-"),
              CommandLine.arguments.count > 1 else {
            fatalError("Run only via store/tools/capture.rb in its isolated app bundle")
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.appearance = NSAppearance(named: .aqua)
        app.finishLaunching()

        let suite = identifier + ".fixtures"
        let defaults = UserDefaults(suiteName: suite)!
        precondition(defaults.persistentDomain(forName: suite) == nil)
        defer {
            defaults.removePersistentDomain(forName: suite)
            UserDefaults.standard.removePersistentDomain(forName: identifier)
        }
        defaults.setPersistentDomain([
            "snippets": Data("[]".utf8),
            "migrated-snippet-archive-v1": true,
            "migrated-snippet-archive-dedup-v3": true,
            "migrated-snippet-dl2desk-v1": true,
            "auto-backup-enabled": false,
            "big-year-system-calendar-enabled": false,
            "app-language": "en"
        ], forName: suite)
        let settings = AppSettings(defaults: defaults)
        precondition(settings.snippets.isEmpty && !settings.autoBackupEnabled)
        precondition(settings.autoBackupFolder == nil && !settings.bigYearSystemCalendarEnabled)
        settings.launchpadGridColumns = 7
        settings.launchpadGridRows = 3
        settings.launchpadIconSize = 72
        settings.launchpadAppSortMode = .name
        settings.launchpadGridNavigation = .horizontalPages
        settings.setLaunchShortcut(.init(key: "c", modifier: .option), for: "com.apple.iCal")
        settings.setLaunchShortcut(.init(key: "n", modifier: .option), for: "com.apple.Notes")
        try AppLauncherService.seedStoreCaptureCatalog()
        let catalog = AppLauncherService().loadApps(settings: settings)
        precondition(catalog.count == 19 && catalog.allSatisfy { $0.bundleID.hasPrefix("com.apple.") && $0.snippet == nil })

        // These names and plans are invented fixtures, not imported calendar data.
        settings.bigYearBirthdays = "14.02,!Alex\n22.05,Sam\n09.09,Robin\n12.11,Charlie"
        settings.bigYearEvents = "12.01-16.01.2026,!Project kickoff\n16.03-20.03.2026,Design week\n08.06-12.06.2026,!Summer launch\n10.08-21.08.2026,Holiday\n05.10-09.10.2026,Workshop\n21.12-31.12.2026,Winter break"
        precondition(BigYearData.events(from: settings.bigYearEvents).count == 6)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        if CommandLine.arguments.contains("--search") {
            try captureSearch(settings: settings, to: output)
            return
        }
        try capture(LaunchpadOverlayRootView(settings: settings, displayID: nil),
                    to: output.appendingPathComponent("launchpad.png"))
        try capture(BigYearRootView(year: 2026, settings: settings, onClose: {}),
                    to: output.appendingPathComponent("big-year.png"))
    }

    @MainActor
    static func captureSearch(settings: AppSettings, to output: URL) throws {
        let rect = NSRect(x: 0, y: 0, width: 1600, height: 1000)
        let host = NSHostingView(rootView: LaunchpadOverlayRootView(settings: settings, displayID: nil))
        host.sizingOptions = []
        let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.contentView = host
        host.frame = rect
        defer { window.contentView = nil; window.close() }
        func settle(_ seconds: Double) {
            let deadline = Date().addingTimeInterval(seconds)
            repeat {
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            } while Date() < deadline
        }
        func fields(_ view: NSView) -> [NSTextField] {
            (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap { fields($0) }
        }
        settle(3)
        let inputs = fields(host).filter { $0.isEditable }
        precondition(inputs.count == 1, "Expected the existing native search text field")
        let field = inputs[0]
        var evidence: [[String: Any]] = []
        var frame = 0
        // Each notification follows AppKit's real text-editing delegate path to $query.
        // No global events, focus acquisition, Return, button actions or clipboard access.
        for (query, count) in [("", 24), ("c", 12), ("ca", 12), ("cal", 36), ("ca", 6), ("c", 6), ("", 24)] {
            field.stringValue = query
            NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: field)
            (field.currentEditor() as? NSTextView)?.setSelectedRange(NSRange(location: query.utf16.count, length: 0))
            settle(0.15)
            for index in 0..<count {
                precondition(!window.isVisible && !window.isKeyWindow && !NSApp.isActive)
                host.layoutSubtreeIfNeeded()
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1600, pixelsHigh: 1000,
                                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                              isPlanar: false, colorSpaceName: .deviceRGB,
                                              bytesPerRow: 0, bitsPerPixel: 0)!
                host.cacheDisplay(in: host.bounds, to: bitmap)
                if index == 0 {
                    // Hidden SwiftUI hosts expose no AX children. Verify actual rendered
                    // grid labels instead, excluding the search bar and the dock.
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = ["en-US"]
                    request.usesLanguageCorrection = false
                    request.regionOfInterest = CGRect(x: 0, y: 0.15, width: 1, height: 0.73)
                    try VNImageRequestHandler(cgImage: bitmap.cgImage!, options: [:]).perform([request])
                    let visible = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.sorted()
                    evidence.append(["query": query, "firstFrame": frame, "frames": count, "renderedGridLabels": visible])
                    print("Search \(query.debugDescription): \(visible)")
                }
                let png = bitmap.representation(using: .png, properties: [:])!
                precondition(png.count > 20_000)
                try png.write(to: output.appendingPathComponent(String(format: "frame-%04d.png", frame)), options: .atomic)
                frame += 1
                settle(1.0 / 15)
            }
        }
        try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("search-evidence.json"), options: .atomic)
        let initial = evidence[0]["renderedGridLabels"] as! [String]
        let filtered = evidence[3]["renderedGridLabels"] as! [String]
        let restored = evidence[6]["renderedGridLabels"] as! [String]
        precondition(initial != filtered && initial == restored, "Native search must change results and reset")
        precondition(filtered.contains("Calendar") && filtered.contains("Calculator"), "Expected cal results")
        precondition(initial.contains("Weather") && !filtered.contains("Weather"), "Nonmatching grid result must disappear")
        print("Verified native search results changed and reset; captured \(frame) frames")
    }

    @MainActor
    static func capture<V: View>(_ view: V, to url: URL) throws {
        let rect = NSRect(x: 0, y: 0, width: 1600, height: 1000)
        let host = NSHostingView(rootView: view.frame(width: rect.width, height: rect.height))
        let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.contentView = host
        host.frame = rect
        // Never order the window onscreen or make it key. AppKit mounts real
        // representables and runs onAppear/catalog loading in this hidden host.
        let deadline = Date().addingTimeInterval(3)
        repeat {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1600, pixelsHigh: 1000,
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                           isPlanar: false, colorSpaceName: .deviceRGB,
                                           bytesPerRow: 0, bitsPerPixel: 0) else {
            fatalError("Cannot allocate native capture bitmap")
        }
        host.cacheDisplay(in: rect, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]),
              let decoded = NSBitmapImageRep(data: png),
              decoded.pixelsWide == 1600, decoded.pixelsHigh == 1000,
              png.count > 20_000 else { fatalError("Empty or invalid capture: \(url.path)") }
        try png.write(to: url, options: .atomic)
        window.contentView = nil
        window.close()
        print("Captured \(url.path): 1600x1000, \(png.count) bytes")
    }
}
