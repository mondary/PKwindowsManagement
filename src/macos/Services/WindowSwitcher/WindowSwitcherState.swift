import Foundation
import CoreGraphics

struct WindowSwitcherID: Hashable, Sendable {
    let pid: Int32
    let windowID: UInt32
}

struct WindowSwitcherItem: Identifiable, Equatable, Sendable {
    let id: WindowSwitcherID
    let appName: String
    let title: String
    let isMinimized: Bool
    let isHidden: Bool
    let isFullScreen: Bool
    let isOnScreen: Bool

    var displayTitle: String { title.isEmpty ? appName : title }
}

/// Pure selection rules shared by the keyboard, search field and grid.
enum WindowSwitcherState {
    static func filtered(_ items: [WindowSwitcherItem], query: String) -> [WindowSwitcherItem] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return items.filter { item in
            let text = item.appName + " " + item.title
            return words.allSatisfy {
                text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    static func selection(in items: [WindowSwitcherItem], keeping id: WindowSwitcherID?) -> WindowSwitcherID? {
        if let id, items.contains(where: { $0.id == id }) { return id }
        return items.first?.id
    }

    static func moved(in items: [WindowSwitcherItem], from id: WindowSwitcherID?, by offset: Int,
                      wrapping: Bool) -> WindowSwitcherID? {
        guard !items.isEmpty else { return nil }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return items.first?.id }
        let next = wrapping
            ? ((index + offset) % items.count + items.count) % items.count
            : min(max(index + offset, 0), items.count - 1)
        return items[next].id
    }

    static func initialSelection(in items: [WindowSwitcherItem], focused: WindowSwitcherID?) -> WindowSwitcherID? {
        // A switcher opens on the next window when the current window is first.
        if items.count > 1, items.first?.id == focused { return items[1].id }
        return items.first?.id
    }

    static func thumbnailSize(for size: CGSize) -> CGSize {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            return CGSize(width: 480, height: 300)
        }
        let scale = min(480 / size.width, 300 / size.height, 1)
        return CGSize(width: max(1, (size.width * scale).rounded()),
                      height: max(1, (size.height * scale).rounded()))
    }
}
