import Foundation
import CoreGraphics

@main
enum WindowSwitcherChecks {
    static func main() {
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
        precondition(WindowSwitcherState.initialSelection(in: [], focused: nil) == nil)
        precondition(WindowSwitcherState.initialSelection(in: items, focused: nil) == items[0].id)
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
        precondition(WindowSwitcherState.commandTabSelection(in: [], focused: nil, offset: -1) == nil)
        // Quitting an app removes all of its windows at once.
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: items, selected: items[0].id) == items[16].id)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: items, selected: items[4].id) == items[16].id)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: items, selected: items[40].id) == items[40].id)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 103, in: items, selected: items[63].id) == items[47].id)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: [items[0]], selected: items[0].id) == nil)
        precondition(WindowSwitcherState.selectionAfterQuitting(pid: 100, in: [], selected: nil) == nil)
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
        precondition(WindowSwitcherState.selectionAfterClosing(items[0].id, in: [], selected: nil) == nil)
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
        precondition(WindowSwitcherState.moved(in: [], from: nil, by: 1, wrapping: true) == nil)
        precondition(WindowSwitcherState.moved(in: items, from: nil, by: -1, wrapping: true) == items[0].id)

        // Extreme aspect ratios, Retina windows and unavailable geometry stay bounded.
        for size in [CGSize(width: 3440, height: 1440), CGSize(width: 100, height: 9000),
                     CGSize(width: 1, height: 1), .zero, CGSize(width: -1, height: 2),
                     CGSize(width: CGFloat.infinity, height: 50)] {
            let result = WindowSwitcherState.thumbnailSize(for: size)
            precondition(result.width >= 1 && result.width <= 480)
            precondition(result.height >= 1 && result.height <= 300)
        }
        let portrait = WindowSwitcherState.thumbnailSize(for: CGSize(width: 1000, height: 2000))
        precondition(portrait == CGSize(width: 150, height: 300))
        print("Window switcher checks passed: search/accents, identity, 1–64 windows, filtering/closure selection, grid navigation and bounded thumbnails")
    }
}
