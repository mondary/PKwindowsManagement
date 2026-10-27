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
    /// Return/keypad Enter confirms with or without Command/Shift held.
    /// Control/Option combinations remain available to other picker actions.
    static func confirmsWindowSelection(keyCode: UInt16, control: Bool, option: Bool) -> Bool {
        (keyCode == 36 || keyCode == 76) && !control && !option
    }

    /// The picker only lists apps that own user-facing windows. Menu-bar-only
    /// apps (system monitors, launchers, clipboard managers…) and widget hosts
    /// are accessory/prohibited apps: they expose HUD, popover or desktop
    /// windows, never normal app windows. `NSApplication.ActivationPolicy`
    /// raw values are stable: 0 = regular, 1 = accessory, 2 = prohibited.
    static func includesApplication(activationPolicy: Int, bundleIdentifier: String?) -> Bool {
        guard activationPolicy == 0 else { return false }
        guard let bundleIdentifier else { return true }
        return !excludedBundleIdentifiers.contains(bundleIdentifier)
    }

    /// Defense in depth: these system agents are accessory today, but a
    /// transient policy change must never put widgets or desktop chrome back
    /// into the picker.
    private static let excludedBundleIdentifiers: Set<String> = [
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.dock",
        "com.apple.WindowManager",
        "com.apple.wallpaper.agent",
        "com.apple.MenuBarAgent",
        "com.apple.loginwindow",
        "com.apple.coreservices.uiagent",
        "com.apple.Spotlight",
        "com.apple.OSDUIHelper"
    ]

    /// Sticky ⌘Tab only defers the release commit while a filter is being
    /// refined. An empty query leaves nothing to type, so releasing ⌘ must
    /// still activate the selected window, like the system switcher.
    static func defersCommandTabCommit(sticky: Bool, query: String) -> Bool {
        guard sticky else { return false }
        return !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

    static func selectionAfterClosing(_ removed: WindowSwitcherID, in items: [WindowSwitcherItem],
                                      selected: WindowSwitcherID?) -> WindowSwitcherID? {
        let remaining = items.filter { $0.id != removed }
        guard !remaining.isEmpty else { return nil }
        if selected != removed { return selection(in: remaining, keeping: selected) }
        let index = items.firstIndex { $0.id == removed } ?? 0
        return remaining[min(index, remaining.count - 1)].id
    }

    /// Quitting an app removes every window it owns. Keep an unrelated
    /// selection, otherwise move to the nearest window that survived.
    static func selectionAfterQuitting(pid: Int32, in items: [WindowSwitcherItem],
                                       selected: WindowSwitcherID?) -> WindowSwitcherID? {
        let remaining = items.filter { $0.id.pid != pid }
        guard !remaining.isEmpty else { return nil }
        guard let selected, selected.pid == pid else {
            return selection(in: remaining, keeping: selected)
        }
        let index = items.firstIndex { $0.id == selected } ?? 0
        if let next = items[index...].first(where: { $0.id.pid != pid }) { return next.id }
        return remaining[min(index, remaining.count - 1)].id
    }

    /// Hold-⌘ cycling starts on the previously used window, or on the least
    /// recently used one for the first ⇧⌘⇥. Offsets accumulate while the
    /// inventory is still loading.
    static func commandTabSelection(in items: [WindowSwitcherItem], focused: WindowSwitcherID?,
                                    offset: Int) -> WindowSwitcherID? {
        guard !items.isEmpty else { return nil }
        if offset == 0 { return initialSelection(in: items, focused: focused) }
        let index: Int
        if offset > 0 {
            let initial = (items.count > 1 && items.first?.id == focused) ? 1 : 0
            index = (initial + offset) % items.count
        } else {
            index = ((items.count + offset) % items.count + items.count) % items.count
        }
        return items[index].id
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
            return CGSize(width: 640, height: 400)
        }
        let scale = min(640 / size.width, 400 / size.height, 1)
        return CGSize(width: max(1, (size.width * scale).rounded()),
                      height: max(1, (size.height * scale).rounded()))
    }

    /// Grid geometry is shared by the picker layout and the controller so every
    /// card has the same height regardless of the captured window's aspect.
    static let gridSpacing: CGFloat = 12
    static let gridPadding: CGFloat = 16
    static let cardCaptionHeight: CGFloat = 40
    static let cardImageAspectRatio: CGFloat = 1.55

    static func cardHeight(forWidth width: CGFloat, columns: Int) -> CGFloat {
        let columns = max(1, columns)
        let available = max(0, width - gridPadding * 2)
        let cardWidth = (available - CGFloat(columns - 1) * gridSpacing) / CGFloat(columns)
        let imageHeight = min(170, max(150, (cardWidth / cardImageAspectRatio).rounded()))
        return imageHeight + cardCaptionHeight
    }
}
