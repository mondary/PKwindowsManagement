import Foundation
import CoreGraphics

@main
struct ExposeLayoutChecks {
    static func portrait(_ pid: Int32, _ id: UInt32, name: String = "Notes") -> WindowSwitcherItem {
        WindowSwitcherItem(id: .init(pid: pid, windowID: id), appName: name,
            title: "Tall \(id)", isMinimized: false, isHidden: false,
            isFullScreen: false, isOnScreen: true, frame: CGRect(x: 0, y: 0, width: 620, height: 980))
    }

    static func window(_ pid: Int32, _ id: UInt32, name: String = "Chrome",
                       kind: WindowSwitcherItem.ItemKind = .window) -> WindowSwitcherItem {
        WindowSwitcherItem(id: .init(pid: pid, windowID: id), appName: name,
            title: "Window \(id)", isMinimized: false, isHidden: false,
            isFullScreen: false, isOnScreen: true, kind: kind,
            frame: CGRect(x: -1500 + Int(id) * 10, y: -700, width: 900, height: 600))
    }

    static func checkComposition(_ groups: [ExposeLayout.Group], area: CGRect) {
        let layout = ExposeLayout.overview(groups: groups, in: area)
        let items = groups.flatMap(\.windows)
        precondition(layout.windows.count == items.count)
        precondition(Set(layout.windows.map(\.id)) == Set(items.map(\.id)))
        precondition(layout.headings.count == groups.count)
        for (index, heading) in layout.headings.enumerated() {
            precondition(area.insetBy(dx: -0.01, dy: -0.01).contains(heading.bounds))
            for other in layout.headings.dropFirst(index + 1) {
                precondition(!heading.bounds.intersects(other.bounds), "App groups overlap")
            }
        }
        for (index, placement) in layout.windows.enumerated() {
            let total = placement.frame.union(placement.caption)
            precondition(ExposeLayout.valid(placement.frame))
            precondition(area.insetBy(dx: -0.01, dy: -0.01).contains(total))
            for other in layout.windows.dropFirst(index + 1) {
                precondition(!total.intersects(other.frame.union(other.caption)), "Window previews/captions overlap")
            }
            for heading in layout.headings { precondition(!total.intersects(heading.frame)) }
            precondition(items.first { $0.id == placement.id } == placement.item, "Original geometry was mutated")
            if let original = placement.item.frame {
                let originalAspect = original.width / original.height
                precondition(abs(placement.frame.width / placement.frame.height - originalAspect) < 0.0001)
            }
        }
        precondition(layout == ExposeLayout.overview(groups: groups, in: area), "Layout must be deterministic")
    }

    static func main() {
        let originals = [window(10, 1), window(20, 2, name: "Editor"), window(10, 3),
            window(11, 4), window(30, 5, name: "Editor"), window(10, 6)]
        let groups = ExposeLayout.groups(originals + [originals[0], window(40, 0, kind: .dockApp)],
            identities: [10: "bundle:chrome", 11: "bundle:chrome", 20: "bundle:editor-a", 30: "bundle:editor-b"])
        precondition(groups.map(\.id) == ["bundle:chrome", "bundle:editor-a", "bundle:editor-b"])
        precondition(groups[0].windows.map { $0.id.windowID } == [1, 3, 4, 6])
        precondition(groups.flatMap(\.windows).count == originals.count)
        precondition(ExposeLayout.groups([window(10, 1), window(11, 2)], identities: [:]).count == 2)
        precondition(ExposeLayout.groups([], identities: [:]).isEmpty)

        for size in [CGSize(width: 320, height: 260), CGSize(width: 640, height: 400),
                     CGSize(width: 1280, height: 600), CGSize(width: 2560, height: 1200)] {
            let area = CGRect(origin: CGPoint(x: -1800, y: -1000), size: size)
            for count in 0...128 {
                let windows = (0..<count).map { window(10 + Int32($0 % 9), UInt32($0 + 1)) }
                checkComposition(ExposeLayout.groups(windows, identities: [:]), area: area)
                checkComposition(ExposeLayout.groups(windows, identities: Dictionary(uniqueKeysWithValues: (10...18).map { (Int32($0), "one-app") })), area: area)
            }
        }
        let chrome = ExposeLayout.groups([window(10, 1), window(10, 2), window(10, 3)], identities: [:])
        let trio = ExposeLayout.overview(groups: chrome, in: CGRect(x: 0, y: 0, width: 1200, height: 700))
        precondition(trio.windows.count == 3)
        precondition(abs(trio.windows[0].frame.midY - trio.windows[2].frame.midY) < 0.001)
        precondition(trio.windows[0].frame.maxX < trio.windows[1].frame.minX)
        precondition(ExposeLayout.overview(groups: groups, in: .zero).windows.isEmpty)
        precondition(ExposeLayout.overview(groups: groups, in: .null).windows.isEmpty)

        let display = CGRect(x: -1920, y: -1080, width: 1920, height: 1080)
        let original = window(10, 1)
        precondition(ExposeLayout.sourceFrame(for: original, on: display) == original.frame)
        precondition(ExposeLayout.local(original.frame!, on: display).origin == CGPoint(x: 430, y: 380))
        var minimized = original
        minimized = WindowSwitcherItem(id: original.id, appName: original.appName, title: original.title,
            isMinimized: true, isHidden: false, isFullScreen: false, isOnScreen: false, frame: original.frame)
        precondition(ExposeLayout.sourceFrame(for: minimized, on: display).size == CGSize(width: 1, height: 1))
        let displays = [ExposeLayout.Display(name: "Main", frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            .init(name: "Left", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080)),
            .init(name: "Above", frame: CGRect(x: 0, y: -1200, width: 1920, height: 1200))]
        precondition(ExposeLayout.displayName(for: CGRect(x: -800, y: 100, width: 1000, height: 600), displays: displays) == "Left")
        precondition(ExposeLayout.displayName(for: CGRect(x: 200, y: -900, width: 800, height: 600), displays: displays) == "Above")
        precondition(ExposeLayout.displayName(for: nil, displays: displays) == nil)
        precondition(ExposeLayout.adjacentGroup(in: groups, selected: groups[0].windows[0].id, delta: -1) == groups[2].windows[0].id)
        precondition(ExposeLayout.adjacentGroup(in: [], selected: nil, delta: 1) == nil)
        // Islands are spread across the whole surface, not a globally scaled
        // shelf centered on the wallpaper. Small apps keep their own scale.
        let largeArea = CGRect(x: -1440, y: 80, width: 1400, height: 760)
        let islandLayout = ExposeLayout.overview(groups: groups, in: largeArea)
        let occupied = islandLayout.headings.reduce(CGRect.null) { $0.union($1.bounds) }
        precondition(abs(occupied.width - largeArea.width) < 0.01)
        precondition(abs(occupied.height - largeArea.height) < 0.01)
        let solo = ExposeLayout.overview(groups: ExposeLayout.groups([window(10, 1)], identities: [:]), in: largeArea)
        precondition(solo.windows[0].frame.width * solo.windows[0].frame.height > largeArea.width * largeArea.height * 0.65)
        for placement in islandLayout.windows {
            let center = CGPoint(x: placement.frame.midX, y: placement.frame.midY)
            precondition(ExposeLayout.hitTest(center, in: islandLayout, offset: 0, visibleArea: largeArea) == placement.id)
        }
        // The strip has large individual previews and bounded horizontal travel.
        for count in 0...128 {
            let windows = (0..<count).map { window(10 + Int32($0 % 7), UInt32($0 + 1)) }
            let strip = ExposeLayout.strip(groups: ExposeLayout.groups(windows, identities: [:]), in: largeArea)
            precondition(strip.windows.count == count && strip.contentWidth.isFinite)
            for (index, placement) in strip.windows.enumerated() {
                precondition(placement.frame.height > largeArea.height * 0.75)
                precondition(placement.frame.width > largeArea.width * 0.7)
                for other in strip.windows.dropFirst(index + 1) {
                    precondition(!placement.frame.union(placement.caption).intersects(other.frame.union(other.caption)))
                }
                let offset = ExposeLayout.clampedOffset(placement.frame.midX - largeArea.midX,
                    contentWidth: strip.contentWidth, viewportWidth: largeArea.width)
                let center = CGPoint(x: placement.frame.midX - offset, y: placement.frame.midY)
                precondition(ExposeLayout.hitTest(center, in: strip, offset: offset, visibleArea: largeArea) == placement.id)
                precondition(offset >= 0 && offset <= max(0, strip.contentWidth - largeArea.width))
            }
        }
        // Portrait windows take a narrower card instead of transparent side
        // bands; the empty space becomes visible card surface, keeping the
        // strip readable as one continuous row.
        let portraitStrip = ExposeLayout.strip(groups: ExposeLayout.groups([portrait(50, 1), portrait(50, 2)], identities: [:]), in: largeArea)
        for placement in portraitStrip.windows {
            precondition(placement.frame.width / placement.frame.height > 0.55 && placement.frame.width / placement.frame.height < 0.75)
        }
        let mixed = ExposeLayout.strip(groups: ExposeLayout.groups([window(10, 1), portrait(50, 2), window(20, 3, name: "Editor")], identities: [:]), in: largeArea)
        precondition(mixed.windows[0].frame.width > mixed.windows[1].frame.width * 1.3)
        precondition(mixed.windows[1].frame.width < mixed.windows[2].frame.width)
        precondition(ExposeLayout.clampedOffset(-50, contentWidth: 2000, viewportWidth: 1000) == 0)
        precondition(ExposeLayout.clampedOffset(9999, contentWidth: 2000, viewportWidth: 1000) == 1000)
        precondition(ExposeLayout.clampedOffset(.nan, contentWidth: 2000, viewportWidth: 1000) == 0)
        // Mouse coordinates are AppKit bottom-left; overlay targets are Quartz top-left.
        precondition(ExposeLayout.quartzPoint(fromLocal: CGPoint(x: 100, y: 100), on: display)
            == CGPoint(x: -1820, y: -100))
        var click = ExposeLayout.ClickSelection()
        let clicked = window(10, 1).id, other = window(20, 2).id
        precondition(click.press(clicked))
        precondition(click.release(over: clicked) == clicked) // Never substitute current keyboard/hover selection.
        precondition(!click.hasPress && click.release(over: clicked) == nil) // One click, one activation.
        precondition(click.press(clicked) && click.release(over: other) == nil) // Drag to another window cancels.
        precondition(click.press(clicked) && click.release(over: nil) == nil) // Background release cancels.
        precondition(!click.press(nil))
        precondition(ExposeLayout.Mode(rawValue: "islands") == .islands)
        precondition(ExposeLayout.Mode(rawValue: "strip") == .strip)
        print("Exposé checks passed: spatial islands fill the display, large scrollable strip (0–128), no overlap, bounds/aspects, scrolled hit regions, exact single-click identity and drag cancellation")
    }
}
