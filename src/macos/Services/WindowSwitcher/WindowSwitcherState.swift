import Foundation
import CoreGraphics

struct WindowSwitcherID: Hashable, Sendable {
    let pid: Int32
    let windowID: UInt32
}

enum WindowSwitcherTarget: Hashable {
    case item(WindowSwitcherID)
    case room(String)
}

struct WindowSwitcherItem: Identifiable, Equatable, Sendable {
    enum ItemKind: Equatable, Sendable {
        case window
        /// Running Dock app, whether or not it also has listed windows.
        case dockApp
        /// Accessory app living in the menu bar.
        case menuBarApp
    }

    let id: WindowSwitcherID
    let appName: String
    let title: String
    let isMinimized: Bool
    let isHidden: Bool
    let isFullScreen: Bool
    let isOnScreen: Bool
    var kind: ItemKind = .window

    var displayTitle: String { title.isEmpty ? appName : title }
    var isProcess: Bool { kind != .window }
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

    /// Coarse eligibility; an accessory activation policy alone is NOT proof
    /// that a process is a menu-bar app. Bundle structure is checked below.
    static func isListedProcess(activationPolicy: Int, bundleIdentifier: String?) -> Bool {
        guard activationPolicy == 0 || activationPolicy == 1 else { return false }
        guard let bundleIdentifier else { return activationPolicy == 0 }
        let identifier = bundleIdentifier.lowercased()
        if activationPolicy == 1 && identifier.hasPrefix("com.apple.") { return false }
        return !excludedBundleIdentifiers.contains(where: { $0.lowercased() == identifier })
    }

    struct ApplicationIdentity {
        let pid: Int32
        let activationPolicy: Int
        let bundleIdentifier: String?
        let bundlePath: String?
    }

    /// Only standalone app bundles are targets. Never promote a nested helper
    /// to its owner: activation/quit must address the actual visible app PID.
    /// Steam reports pid -1 and a `Steam.AppBundle/Steam` launcher path: both
    /// a non-zero pid (including -1) and an .AppBundle wrapper mean "real app".
    static func applicationIdentityKey(_ app: ApplicationIdentity) -> String? {
        guard app.pid != 0,
              isListedProcess(activationPolicy: app.activationPolicy, bundleIdentifier: app.bundleIdentifier),
              let path = app.bundlePath, !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let components = url.pathComponents.map { $0.lowercased() }
        let last = components.last ?? ""
        let parent = components.count >= 2 ? components[components.count - 2] : ""
        let standaloneBundle = last.hasSuffix(".app") || parent.hasSuffix(".appbundle")
        guard standaloneBundle else { return nil }
        // LoginItems, Frameworks, XPCServices and embedded apps belong to the
        // enclosing product, not to a second Applications tile.
        guard !components.dropLast().contains(where: {
            $0.hasSuffix(".app") || $0.hasSuffix(".framework") || $0.hasSuffix(".xpc")
                || $0 == "contents" || $0 == "loginitems" || $0 == "xpcservices"
                || $0 == "helpers"
        }) else { return nil }
        let lowerPath = url.path.lowercased()
        let identifier = app.bundleIdentifier?.lowercased()
        if lowerPath.hasPrefix("/system/library/") {
            // Finder is a genuine user application installed in CoreServices.
            guard identifier == "com.apple.finder", app.activationPolicy == 0,
                  lowerPath == "/system/library/coreservices/finder.app" else { return nil }
        }
        if let identifier {
            let parts = identifier.split(separator: ".")
            let internalRoles: Set<Substring> = ["helper", "helpers", "xpc", "renderer", "gpu", "crashpad", "updater"]
            guard !parts.contains(where: { internalRoles.contains($0) }) else { return nil }
            return "bundle:" + identifier
        }
        return "path:" + url.path
    }

    /// One entry per exact bundle identity, not per vendor/name prefix. Prefer
    /// the regular (Dock) process if multiple instances share the same bundle.
    /// Preserve the inventory order and therefore the visible keyboard order.
    /// Returns identities: pid-less apps (Steam reports -1) must NOT collapse
    /// into a single PID key.
    static func listedApplications(_ apps: [ApplicationIdentity]) -> [ApplicationIdentity] {
        var keys: [String] = []
        var representatives: [String: ApplicationIdentity] = [:]
        for app in apps {
            guard let key = applicationIdentityKey(app) else { continue }
            if let previous = representatives[key] {
                if previous.activationPolicy != 0 && app.activationPolicy == 0 {
                    representatives[key] = app
                }
            } else {
                keys.append(key)
                representatives[key] = app
            }
        }
        return keys.compactMap { representatives[$0] }
    }

    /// The picker section a listed process belongs to.
    static func processKind(activationPolicy: Int) -> WindowSwitcherItem.ItemKind? {
        switch activationPolicy {
        case 0: return .dockApp
        case 1: return .menuBarApp
        default: return nil
        }
    }

    /// Single keyboard stream: filtered windows first, then the filtered
    /// process sections, so arrows/Tab walk from the grid into the lists.
    static func navigationItems(windows: [WindowSwitcherItem], processes: [WindowSwitcherItem]) -> [WindowSwitcherItem] {
        windows + processes
    }

    /// The picker is one keyboard stream, ordered exactly like its visible
    /// sections: windows, running Dock/menu-bar apps, then Rooms.
    static func navigationTargets(windows: [WindowSwitcherItem], apps: [WindowSwitcherItem],
                                  roomIDs: [String]) -> [WindowSwitcherTarget] {
        windows.map { .item($0.id) }
            + apps.map { .item($0.id) }
            + roomIDs.map { .room($0) }
    }

    static func selection(in targets: [WindowSwitcherTarget], keeping target: WindowSwitcherTarget?) -> WindowSwitcherTarget? {
        if let target, targets.contains(target) { return target }
        return targets.first
    }

    static func initialSelection(in targets: [WindowSwitcherTarget], focused: WindowSwitcherID?) -> WindowSwitcherTarget? {
        guard !targets.isEmpty else { return nil }
        if targets.count > 1, targets.first == focused.map(WindowSwitcherTarget.item) { return targets[1] }
        return targets.first
    }

    /// Mirrors the system switcher's first/next/backward behavior, but keeps
    /// the ordered target list broad enough to include app and Room sections.
    static func commandTabSelection(in targets: [WindowSwitcherTarget], focused: WindowSwitcherID?,
                                    offset: Int) -> WindowSwitcherTarget? {
        guard !targets.isEmpty else { return nil }
        let initial = (targets.count > 1 && targets.first == focused.map(WindowSwitcherTarget.item)) ? 1 : 0
        let index: Int
        if offset == 0 {
            index = initial
        } else if offset > 0 {
            index = (initial + offset) % targets.count
        } else {
            index = ((targets.count + offset) % targets.count + targets.count) % targets.count
        }
        return targets[index]
    }

    static func moved(in targets: [WindowSwitcherTarget], from target: WindowSwitcherTarget?, by offset: Int,
                      wrapping: Bool) -> WindowSwitcherTarget? {
        guard !targets.isEmpty else { return nil }
        guard let index = targets.firstIndex(of: target ?? targets[0]) else { return targets.first }
        let next = wrapping
            ? ((index + offset) % targets.count + targets.count) % targets.count
            : min(max(index + offset, 0), targets.count - 1)
        return targets[next]
    }

    static func selectionAfterClosing(_ removed: WindowSwitcherID, in targets: [WindowSwitcherTarget],
                                      selected: WindowSwitcherTarget?) -> WindowSwitcherTarget? {
        let remaining = targets.filter { $0 != .item(removed) }
        guard !remaining.isEmpty else { return nil }
        if selected != .item(removed) { return selection(in: remaining, keeping: selected) }
        let index = targets.firstIndex(of: .item(removed)) ?? 0
        return remaining[min(index, remaining.count - 1)]
    }

    static func selectionAfterQuitting(pid: Int32, in targets: [WindowSwitcherTarget],
                                       selected: WindowSwitcherTarget?) -> WindowSwitcherTarget? {
        let remaining = targets.filter { target in
            guard case .item(let id) = target else { return true }
            return id.pid != pid
        }
        guard !remaining.isEmpty else { return nil }
        guard let selected, case .item(let selectedID) = selected, selectedID.pid == pid else {
            return selection(in: remaining, keeping: selected)
        }
        let index = targets.firstIndex(of: selected) ?? 0
        if let next = targets[index...].first(where: { target in
            guard case .item(let id) = target else { return true }
            return id.pid != pid
        }), remaining.contains(next) { return next }
        return remaining[min(index, remaining.count - 1)]
    }

    /// The regular-app inventory and the broader Dock/menu-bar inventory
    /// overlap by design. Build icon lookup maps without Dictionary's
    /// duplicate-key trap when the same running app appears in both lists.
    static func uniqueValuesByPID<Value>(_ entries: [(pid: Int32, value: Value)]) -> [Int32: Value] {
        var result: [Int32: Value] = [:]
        for entry in entries where result[entry.pid] == nil {
            result[entry.pid] = entry.value
        }
        return result
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
