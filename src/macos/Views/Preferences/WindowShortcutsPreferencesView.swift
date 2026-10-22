import SwiftUI

struct WindowShortcutsPreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var canvas = HorizontalCanvasService.shared
    @ObservedObject private var registrationFeedback = ShortcutRegistrationFeedback.shared

    private var halvesEntries: [WindowCommandSpec] { WindowCommandCatalog.halves }

    private var moveEntries: [WindowCommandSpec] { WindowCommandCatalog.move }

    private var quartersEntries: [WindowCommandSpec] { WindowCommandCatalog.quarters }

    private var fourthsEntries: [WindowCommandSpec] { WindowCommandCatalog.fourths }

    private var thirdsEntries: [WindowCommandSpec] { WindowCommandCatalog.thirds }

    private var twoThirdsEntries: [WindowCommandSpec] { WindowCommandCatalog.twoThirds }

    private var threeFourthsEntries: [WindowCommandSpec] { WindowCommandCatalog.threeFourths }

    private var horizontalEntries: [WindowCommandSpec] { WindowCommandCatalog.horizontal }

    private var sixthsEntries: [WindowCommandSpec] { WindowCommandCatalog.sixths }

    private var displaysEntries: [WindowCommandSpec] { WindowCommandCatalog.displays }

    private var desktopsEntries: [WindowCommandSpec] { WindowCommandCatalog.desktops }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(localizedString("Window management"))
                        .font(.title3.weight(.semibold))

                    conflictsCard

                    windowSwitcherSection

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Rooms", systemImage: "rectangle.3.group")
                                .font(.headline)
                            Spacer()
                            Button(localizedString("Manage Rooms…")) { SettingsWindowController.shared.showRooms() }
                            Button(localizedString("Open Rooms")) { RoomsOverlayController.shared.show() }
                            Text("⌃⌥R").font(.body.monospaced()).foregroundStyle(.secondary)
                        }
                        Text(localizedString("Create a room from selected windows, choose its screen and layout, then reopen or minimize it from the Rooms panel."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

                    KeyboardShortcutMapView(settings: settings, availableWidth: max(0, geometry.size.width - 48))

                    if geometry.size.width >= 760 {
                        wideLayout
                    } else {
                        narrowLayout
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: - Conflits de raccourcis

    /// Carte d'alerte : combinaisons partagées par plusieurs liaisons et refus
    /// d'enregistrement macOS. Elle nomme la liaison qui s'exécute réellement.
    @ViewBuilder
    private var conflictsCard: some View {
        let groups = conflictGroups
        let refusals = registrationFeedback.refusals
        if !groups.isEmpty || !refusals.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label(localizedString("Shortcut conflicts"), systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                ForEach(refusals) { refusal in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            shortcutBadge(refusal.shortcut)
                            Text(refusal.title)
                        }
                        Text(localizedString("macOS refused this shortcut — another app already owns it. Pick another one."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        shortcutBadge(group.shortcut)
                        ForEach(Array(group.bindings.enumerated()), id: \.element.id) { index, binding in
                            HStack(spacing: 8) {
                                Image(systemName: index == 0 ? "circle.inset.filled" : "circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(index == 0 ? Color.orange : Color.secondary)
                                Text(binding.title)
                                    .font(.body)
                                Spacer()
                                if index == 0 {
                                    Text(localizedString("Runs"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                } else if binding.kind.isClearable {
                                    Button(localizedString("Clear")) { clearBinding(binding) }
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                }

                Text(localizedString("On key press, the first binding in each list runs; the others stay inert until you change one."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    /// Toutes les liaisons globales que cette page peut confronter : commandes
    /// de fenêtres, Launchpad, Rooms et lancements d'app/script.
    private var shortcutBindings: [ShortcutBindingRef] {
        var bindings: [ShortcutBindingRef] = ShortcutAction.allCases.compactMap { action in
            guard let shortcut = settings.shortcut(for: action) else { return nil }
            return ShortcutBindingRef(kind: .windowAction(action), title: action.title, shortcut: shortcut)
        }
        bindings.append(.init(kind: .launchpad, title: localizedString("Open Launchpad"), shortcut: settings.launchpadShortcut))
        bindings.append(.init(kind: .rooms, title: localizedString("Open Rooms"), shortcut: .init(key: "r", modifier: .controlOption)))
        for (id, shortcut) in settings.launchShortcuts {
            bindings.append(.init(kind: .launch(id: id), title: launchTitle(for: id), shortcut: shortcut))
        }
        return bindings
    }

    private var conflictGroups: [ShortcutConflictGroup] {
        ShortcutConflictEngine.conflictGroups(shortcutBindings)
    }

    /// Texte d'aide de la ligne : nil quand le raccourci est unique.
    private func conflictNote(for action: ShortcutAction) -> String? {
        guard let group = conflictGroups.first(where: { $0.bindings.contains { $0.kind == .windowAction(action) } }) else {
            return nil
        }
        let others = group.bindings.filter { $0.kind != .windowAction(action) }
        let names = others.map { "\($0.title) (\(shortcutBadgeText($0.shortcut)))" }.joined(separator: ", ")
        if group.winner.kind == .windowAction(action) {
            return String(format: localizedString("Also used by %@ — this line runs."), names)
        }
        return String(format: localizedString("Also used by %@ — on key press, %@ runs instead."), names, group.winner.title)
    }

    private func clearBinding(_ binding: ShortcutBindingRef) {
        switch binding.kind {
        case .windowAction(let action): settings.clearShortcut(for: action)
        case .launch(let id): settings.setLaunchShortcut(nil, for: id)
        case .launchpad, .rooms: break
        }
    }

    private static var launchNames: [String: String] = [:]

    private func launchTitle(for id: String) -> String {
        if let snippet = settings.snippets.first(where: { $0.id == id }) { return snippet.title }
        if let cached = Self.launchNames[id] { return cached }
        let name: String
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            name = FileManager.default.displayName(atPath: url.path)
        } else {
            name = id
        }
        Self.launchNames[id] = name
        return name
    }

    private func shortcutBadgeText(_ shortcut: KeyboardShortcutSetting) -> String {
        "\(shortcut.modifier.symbolPrefix)\(shortcut.keyDisplayName)"
    }

    private func shortcutBadge(_ shortcut: KeyboardShortcutSetting) -> some View {
        Text(shortcutBadgeText(shortcut))
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.orange.opacity(0.15))
            )
    }

    private var windowSwitcherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(localizedString("Window previews"), systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                Spacer()
                Button(localizedString("Enable previews…")) { WindowSwitcherController.shared.requestPreviews() }
                    .help(localizedString("Thumbnails require Screen Recording permission. macOS may ask you to restart the app."))
                Button(localizedString("Open Window Previews")) { WindowSwitcherController.shared.show() }
            }
            Text(localizedString("Find a window by its thumbnail, app or title. Tab browses, Return opens and Escape cancels. Thumbnails require Screen Recording permission."))
                .font(.caption).foregroundStyle(.secondary)
            Toggle(localizedString("Use ⌘Tab to open window previews"), isOn: $settings.windowSwitcherUsesCommandTab)
            Text(localizedString("Replaces the macOS app switcher while enabled. Hold ⌘, press Tab to cycle and release ⌘ to activate. ⌘W closes the selected window; ⌘Q quits its app."))
                .font(.caption).foregroundStyle(.secondary)
            Text(localizedString("Type directly while ⌘ is held to filter windows."))
                .font(.caption).foregroundStyle(.secondary)
            Toggle(localizedString("Keep the picker open when ⌘ is released"), isOn: $settings.windowSwitcherStickyCommandTab)
                .disabled(!settings.windowSwitcherUsesCommandTab)
            Text(localizedString("Releasing ⌘ keeps the picker open. Return activates the selected window; Escape cancels."))
                .font(.caption).foregroundStyle(.secondary)
            Text(localizedString("Close individual windows with ⌘W or the × button. The picker stays open; save dialogs remain under your control."))
                .font(.caption).foregroundStyle(.secondary)
            windowRow(WindowCommandCatalog.switcher)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var wideLayout: some View {
        generalMarginSection()
        canvasSection()

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Halves", entries: halvesEntries)
            sectionCard(title: "Move", entries: moveEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Quarters", entries: quartersEntries)
            sectionCard(title: "Fourth Columns", entries: fourthsEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Third Columns", entries: thirdsEntries)
            sectionCard(title: "Two Thirds", entries: twoThirdsEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Three Fourths", entries: threeFourthsEntries)
            sectionCard(title: "Horizontal", entries: horizontalEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Sixths", entries: sixthsEntries)
            sectionCard(title: "Displays", entries: displaysEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Desktops", entries: desktopsEntries)
            desktopOptionsCard()
        }

        sizeSection()
    }

    @ViewBuilder
    private var narrowLayout: some View {
        generalMarginSection()
        canvasSection()
        sectionCard(title: "Move", entries: moveEntries)
        sectionCard(title: "Halves", entries: halvesEntries)
        sectionCard(title: "Quarters", entries: quartersEntries)
        sectionCard(title: "Fourth Columns", entries: fourthsEntries)
        sectionCard(title: "Third Columns", entries: thirdsEntries)
        sectionCard(title: "Two Thirds", entries: twoThirdsEntries)
        sectionCard(title: "Three Fourths", entries: threeFourthsEntries)
        sectionCard(title: "Horizontal", entries: horizontalEntries)
        sectionCard(title: "Sixths", entries: sixthsEntries)
        sectionCard(title: "Displays", entries: displaysEntries)
        sectionCard(title: "Desktops", entries: desktopsEntries)
        desktopOptionsCard()
        sizeSection()
    }

    private func canvasSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionCard(title: "Horizontal Canvas", entries: WindowCommandCatalog.canvas)
            HStack {
                Button(localizedString("Toggle Horizontal Canvas")) { canvas.perform(.toggle) }
                Button(localizedString("Restore Canvas")) { canvas.perform(.restore) }
                Text(localizedString(canvas.activeDisplayIDs.isEmpty ? "Canvas inactive" : "Canvas active"))
                    .foregroundStyle(.secondary)
            }
            Text(localizedString("Every window starts at full height. Choose half height for one window, then another: the second joins below the first, even from a distant column. Full height separates that window again. Choices survive desktop switching until Canvas exits."))
                .font(.caption).foregroundStyle(.secondary)
            Text(localizedString("Canvas scrolls horizontally with the trackpad, or vertically while holding Option. Ordinary vertical scrolling stays in apps. Previous/next shortcuts move between columns. Exiting restores original positions and sizes."))
                .font(.caption).foregroundStyle(.secondary)
            if !canvas.message.isEmpty {
                Text(canvas.message).font(.caption).foregroundStyle(.orange)
            }
            Button(localizedString("Check Canvas windows")) { canvas.perform(.inspect) }
            if !canvas.inventoryMessage.isEmpty {
                Text(canvas.inventoryMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }

    private func sectionCard(title: String, entries: [WindowCommandSpec]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString(title))
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(entries) { item in
                    windowRow(item)
                    if item.id != entries.last?.id { Divider() }
                }
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sizeSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("Size & Position"))
                .font(.headline)
            VStack(spacing: 0) {
                windowRow(WindowCommandCatalog.size.fullScreen)
                Divider()
                windowRow(WindowCommandCatalog.size.toggleFullScreen)
                Divider()
                windowRow(WindowCommandCatalog.size.almostMaximize)
                Divider()
                windowRow(WindowCommandCatalog.size.maximizeAll)
                Divider()
                windowRow(WindowCommandCatalog.size.maximizeAllInApp)
                Divider()
                windowRow(WindowCommandCatalog.size.tileAll)
                Divider()
                windowRow(WindowCommandCatalog.size.tileAllDesktops)
                Text(localizedString("Bento tiling fills each desktop separately, up to 12 windows per display. Windows shared across desktops are excluded."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                Divider()
                marginEditor($settings.almostFullMargins)
                Divider()
                windowRow(WindowCommandCatalog.size.maximizeHeight)
                Divider()
                windowRow(WindowCommandCatalog.size.maximizeWidth)
                Divider()
                windowRow(WindowCommandCatalog.size.reasonableSize)
                Divider()
                windowRow(WindowCommandCatalog.size.restore)
                Divider()
                windowRow(WindowCommandCatalog.size.makeLarger)
                Divider()
                windowRow(WindowCommandCatalog.size.makeSmaller)
                Divider()
                windowRow(WindowCommandCatalog.size.center)
                Divider()
                marginEditor($settings.centerMargins)
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func desktopOptionsCard() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("New Desktop Options"))
                .font(.headline)
            VStack(spacing: 0) {
                Toggle(isOn: $settings.spaceWallpaperOnCreate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedString("Random wallpaper for new desktops"))
                        Text(localizedString("Picks a different image each time a desktop is created."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

                Divider()

                wallpaperFolderRow

                Divider()

                Toggle(isOn: $settings.spaceFollowMovedWindow) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedString("Follow window when moving"))
                        Text(localizedString("Switch to the destination desktop after moving a window."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

                Divider()

                Text(localizedString("Creating or closing a desktop—and following a moved window when enabled—briefly shows Mission Control. Private macOS APIs may change after system updates."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                Text(localizedString("Desktop reordering keeps its windows together. Disable automatic Spaces rearrangement in macOS to keep your chosen order."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var wallpaperFolderRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString("Wallpaper folder"))
                    .font(.body)
                Text(settings.spaceWallpaperFolder?.path ?? localizedString("No folder selected"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(localizedString("Choose…")) {
                chooseWallpaperFolder()
            }
            .controlSize(.small)
            if settings.spaceWallpaperFolder != nil {
                Button {
                    settings.spaceWallpaperFolder = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(localizedString("Clear"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func chooseWallpaperFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = localizedString("Pick the folder that stores your wallpapers.")
        if panel.runModal() == .OK, let url = panel.url {
            settings.spaceWallpaperFolder = url
        }
    }

    private func generalMarginSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("General Margins"))
                .font(.headline)
            VStack(spacing: 0) {
                Text(localizedString("Applied to every window position."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                marginEditor($settings.generalMargins)
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func windowRow(_ item: WindowCommandSpec) -> some View {
        HStack(spacing: 10) {
            iconPill(item)
            Text(localizedString(item.title))
                .font(.body)
            Spacer()

            if let conflict = conflictNote(for: item.action) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .help(conflict)
                    .accessibilityLabel(conflict)
            }

            CompactShortcutField(shortcut: shortcutBinding(for: item.action))

            Button {
                settings.clearShortcut(for: item.action)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(localizedString("Clear"))

            Button {
                settings.resetShortcut(for: item.action)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(localizedString("Reset"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func iconPill(_ item: WindowCommandSpec) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
            WindowCommandIcon(spec: item)
        }
        .frame(width: 20, height: 20)
    }

    private func marginEditor(_ margins: Binding<WindowMargins>) -> some View {
        HStack(spacing: 16) {
            marginField("Top", margins.top)
            marginField("Bottom", margins.bottom)
            marginField("Left", margins.left)
            marginField("Right", margins.right)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func marginField(_ label: String, _ value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(localizedString(label))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                TextField(localizedString(label), value: Binding(
                    get: { value.wrappedValue },
                    set: { newValue in
                        guard let raw = newValue else { return }
                        value.wrappedValue = min(max(raw, 0), 25)
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(localizedString(label))
                .accessibilityValue("\(value.wrappedValue.formatted()) %")
                .frame(width: 46)
                .onMoveCommand { direction in
                    let step: CGFloat = direction == .up ? 1 : -1
                    value.wrappedValue = min(max(value.wrappedValue + step, 0), 25)
                }
                Text("%")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func shortcutBinding(for action: ShortcutAction) -> Binding<KeyboardShortcutSetting?> {
        Binding(
            get: { settings.shortcut(for: action) },
            set: { shortcut in
                if let shortcut {
                    settings.setShortcut(shortcut, for: action)
                } else {
                    settings.clearShortcut(for: action)
                }
            }
        )
    }
}
