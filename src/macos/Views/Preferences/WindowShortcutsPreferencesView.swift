import SwiftUI

struct WindowShortcutsPreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var canvas = HorizontalCanvasService.shared
    @ObservedObject private var roomStore = RoomStore.shared
    @ObservedObject private var registrationFeedback = ShortcutRegistrationFeedback.shared
    @State private var selectedDisplayUUID: String?

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

    private var focusedWorkspace: TilingWorkspaceSnapshot? {
        if let selectedDisplayUUID,
           let matched = canvas.displayWorkspaces.first(where: { $0.key.displayUUID == selectedDisplayUUID }) {
            return matched
        }
        return canvas.currentWorkspace ?? canvas.displayWorkspaces.first
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PKStudioSectionHeader(
                        title: "Window Studio",
                        subtitle: "Switch each screen between Free, Tiling and Strip (OpenCanvas), or restore saved Room scenes.",
                        systemImage: "macwindow.on.rectangle",
                        tint: PKStudioPalette.tilingAccent
                    ) {
                        HStack(spacing: 8) {
                            Button {
                                RoomsOverlayController.shared.show()
                            } label: {
                                Label(localizedString("Open Rooms"), systemImage: "rectangle.3.group")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                WindowSwitcherController.shared.showExpose()
                            } label: {
                                Label(localizedString("Open Exposé PK"), systemImage: "rectangle.split.3x1")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                WindowSwitcherController.shared.show()
                            } label: {
                                Label(localizedString("Open Window Previews"), systemImage: "rectangle.on.rectangle")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    conflictsCard

                    workspaceModeStudioSection

                    quickBridgesRow

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
        .onAppear {
            canvas.refreshCurrentWorkspace()
            if selectedDisplayUUID == nil {
                selectedDisplayUUID = canvas.currentWorkspace?.key.displayUUID
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

    // MARK: - Studio Modes par Écran (Libre · Tiling · Strip)

    private var workspaceModeStudioSection: some View {
        let activeSnapshot = focusedWorkspace
        let activeMode = activeSnapshot?.profile.workspaceMode ?? .free
        let activeLayout = activeSnapshot?.profile.effectiveTilingLayout ?? .automatic
        let targetUUID = activeSnapshot?.key.displayUUID

        return PKStudioCard(tint: PKStudioPalette.color(for: activeMode), isHighlighted: true, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Label(localizedString("Screen Modes — Free · Tiling · Strip"), systemImage: "display.2")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    if let activeSnapshot {
                        Text(activeSnapshot.displayName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PKStudioPalette.color(for: activeMode).opacity(0.16), in: Capsule())
                            .foregroundStyle(PKStudioPalette.color(for: activeMode))
                    }
                    Spacer()
                    Button {
                        canvas.refreshCurrentWorkspace()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(localizedString("Refresh displays"))
                }

                // Per-display visual selector cards
                if !canvas.displayWorkspaces.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(canvas.displayWorkspaces) { snapshot in
                                let roomName = snapshot.profile.activeRoomID.flatMap { id in
                                    roomStore.rooms.first(where: { $0.id == id })?.name
                                }
                                PKDisplayWorkspaceCard(
                                    snapshot: snapshot,
                                    isFocusedDisplay: snapshot.key.displayUUID == (selectedDisplayUUID ?? canvas.currentWorkspace?.key.displayUUID),
                                    activeRoomName: roomName,
                                    onSelectDisplay: {
                                        selectedDisplayUUID = snapshot.key.displayUUID
                                    },
                                    onSelectMode: { mode in
                                        selectedDisplayUUID = snapshot.key.displayUUID
                                        canvas.setWorkspaceMode(mode, onDisplayUUID: snapshot.key.displayUUID)
                                    }
                                )
                            }
                        }
                    }
                }

                // 3 Large Visual Mode Cards for the focused screen
                HStack(alignment: .top, spacing: 12) {
                    ForEach(WorkspaceWindowMode.allCases) { mode in
                        PKModeSelectorCard(
                            mode: mode,
                            activeLayout: activeLayout,
                            isSelected: activeMode == mode,
                            isEnabled: activeSnapshot != nil
                        ) {
                            canvas.setWorkspaceMode(mode, onDisplayUUID: targetUUID)
                        }
                    }
                }

                // Visual stage for the active mode
                switch activeMode {
                case .tiling:
                    tilingVisualGalleryStage(activeLayout: activeLayout, targetUUID: targetUUID)
                case .strip:
                    stripVisualStudioStage
                case .free:
                    freeModeQuickStage(activeSnapshot: activeSnapshot)
                }

                if !canvas.message.isEmpty {
                    Text(localizedString(canvas.message))
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func tilingVisualGalleryStage(activeLayout: TilingLayoutKind, targetUUID: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(localizedString("Tiling Layout Gallery"), systemImage: "square.grid.3x2.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PKStudioPalette.tilingAccent)
                Spacer()
                Text(activeLayout.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(TilingLayoutKind.tilingCases) { layout in
                    PKTilingLayoutTile(
                        layout: layout,
                        isSelected: activeLayout == layout
                    ) {
                        canvas.setTilingLayout(layout, onDisplayUUID: targetUUID)
                    }
                }
            }

            TilingLayoutPreview(layout: activeLayout, isSelected: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }

    private var stripVisualStudioStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(localizedString("Strip · OpenCanvas / OmniWM Studio"), systemImage: "rectangle.3.group.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PKStudioPalette.stripAccent)
                Spacer()
                Toggle(localizedString("Top minimap bar"), isOn: $settings.canvasMinimap)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: settings.canvasMinimap) { _ in CanvasMinimapController.shared.refresh() }
            }

            HStack(alignment: .top, spacing: 14) {
                TilingLayoutPreview(layout: .canvas, isSelected: true)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    stripFeatureBadge(
                        icon: "arrow.left.and.right.square.fill",
                        keys: "⌃⇧H / ⌃⇧L",
                        title: localizedString("Column navigation & trackpad scroll")
                    )
                    stripFeatureBadge(
                        icon: "rectangle.split.1x2.fill",
                        keys: "⌃⇧S / ⌃⇧F",
                        title: localizedString("Pair any two windows in half-height")
                    )
                    stripFeatureBadge(
                        icon: "arrow.left.arrow.right.circle.fill",
                        keys: "⌃⇧← / ⌃⇧→",
                        title: localizedString("Reorder columns along the ribbon")
                    )

                    HStack(spacing: 8) {
                        Button(localizedString("Check Canvas windows")) {
                            canvas.perform(.inspect)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(localizedString("Restore Free positions")) {
                            canvas.perform(.restore)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    if !canvas.inventoryMessage.isEmpty {
                        Text(canvas.inventoryMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(width: 280, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }

    private func stripFeatureBadge(icon: String, keys: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PKStudioPalette.stripAccent)
                .frame(width: 24, height: 24)
                .background(PKStudioPalette.stripAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(keys)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func freeModeQuickStage(activeSnapshot: TilingWorkspaceSnapshot?) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PKStudioPalette.freeAccent)
                    .frame(width: 30, height: 30)
                    .background(PKStudioPalette.freeAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedString("Free Mode active on this screen"))
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    Text(localizedString("Windows keep their manual positions or your saved Room scene."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !roomStore.rooms.isEmpty {
                Menu {
                    ForEach(roomStore.rooms) { room in
                        Button {
                            let claimed = roomStore.claimedWindowIDs(excluding: room.id)
                            let keepMonocle = canvas.willTile(room)
                            canvas.releaseForRoomActivation(room) { released in
                                guard released else { return }
                                Task {
                                    _ = await RoomEngine().activate(room, claimed: claimed, keepMonocleWindowsVisible: keepMonocle)
                                    await MainActor.run { canvas.resumeAfterRoomActivation(room) }
                                }
                            }
                        } label: {
                            Text("\(room.name) · \(room.placementModeSummary)")
                        }
                    }
                } label: {
                    Label(localizedString("Apply a Room…"), systemImage: "rectangle.3.group.fill")
                }
                .frame(width: 170)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Quick Bridges to Rooms & CMD+Tab Studios

    private var quickBridgesRow: some View {
        HStack(alignment: .top, spacing: 16) {
            PKStudioCard(tint: PKStudioPalette.roomsAccent, padding: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PKStudioPalette.roomsAccent.opacity(0.16))
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PKStudioPalette.roomsAccent)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Rooms")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("⌃⌥R")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PKStudioPalette.roomsAccent.opacity(0.15), in: Capsule())
                                .foregroundStyle(PKStudioPalette.roomsAccent)
                        }
                        Text(localizedString("Save exact window positions or dynamic layouts per project."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(localizedString("Studio Rooms…")) {
                        SettingsWindowController.shared.showRooms()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PKStudioPalette.roomsAccent)
                    .controlSize(.small)
                }
            }

            PKStudioCard(tint: PKStudioPalette.switcherAccent, padding: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PKStudioPalette.switcherAccent.opacity(0.16))
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PKStudioPalette.switcherAccent)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("CMD+Tab")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text(settings.windowSwitcherUsesCommandTab ? "⌘Tab" : "⌃⌥Tab")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PKStudioPalette.switcherAccent.opacity(0.15), in: Capsule())
                                .foregroundStyle(PKStudioPalette.switcherAccent)
                        }
                        Text(localizedString("Visual thumbnails, running apps and Rooms in one switcher."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(localizedString("Studio CMD+Tab…")) {
                        SettingsWindowController.shared.showWindowSwitcherSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PKStudioPalette.switcherAccent)
                    .controlSize(.small)
                }
            }
        }
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
        sectionCard(title: "Horizontal Canvas (Strip · OpenCanvas)", entries: WindowCommandCatalog.canvas)
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
        PKVisualMarginStudio(
            title: "General Margins",
            subtitle: "Applied around every snapped or tiled window.",
            margins: $settings.generalMargins,
            tint: PKStudioPalette.freeAccent
        )
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
        PKVisualMarginStudio(
            title: "Inset Margins",
            subtitle: "Adjust screen padding visually (%)",
            margins: margins,
            tint: PKStudioPalette.tilingAccent
        )
        .padding(10)
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
