import AppKit
import SwiftUI

struct CompactLaunchpadRootView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        CompactLaunchpadView(settings: settings)
            .environment(\.locale, settings.appLanguage.locale)
            .id(settings.appLanguage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeBackground)
            .foregroundColor(themeForeground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var themeBackground: some View {
        switch settings.compactLaunchpadTheme {
        case .light:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.96, green: 0.96, blue: 0.98))
                .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 10)
        case .dark:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.10, green: 0.11, blue: 0.13))
                .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 10)
        case .catpuccin:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.12, green: 0.11, blue: 0.16))
                .shadow(color: Color(red: 0.55, green: 0.34, blue: 0.65).opacity(0.24), radius: 22, x: 0, y: 10)
        case .glass:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private var themeForeground: Color {
        switch settings.compactLaunchpadTheme {
        case .light: return .black
        case .dark: return .white
        case .catpuccin: return Color(red: 0.95, green: 0.92, blue: 0.97)
        case .glass: return .primary
        }
    }
}

private enum SpotlightScope: String, CaseIterable, Identifiable {
    case all
    case apps
    case roomsAndModes
    case snippets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: localizedString("All")
        case .apps: localizedString("Applications")
        case .roomsAndModes: localizedString("Rooms & Modes")
        case .snippets: localizedString("Scripts & Links")
        }
    }

    var icon: String {
        switch self {
        case .all: "sparkles"
        case .apps: "square.grid.2x2"
        case .roomsAndModes: "rectangle.3.group"
        case .snippets: "bolt.horizontal.fill"
        }
    }
}

private enum SpotlightItem: Identifiable {
    case app(LaunchableApp)
    case room(Room)
    case windowMode(WorkspaceWindowMode)

    var id: String {
        switch self {
        case .app(let app): "app:\(app.id)"
        case .room(let room): "room:\(room.id)"
        case .windowMode(let mode): "mode:\(mode.rawValue)"
        }
    }
}

struct CompactLaunchpadView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var roomStore = RoomStore.shared
    @ObservedObject private var canvas = HorizontalCanvasService.shared
    @State private var query = ""
    @State private var scope: SpotlightScope = .all
    @State private var selectedIndex = 0
    @State private var appCatalog: [LaunchableApp] = []
    @State private var commandFeedbackMessage: String?
    @FocusState private var searchFocused: Bool
    private let launcher = AppLauncherService()

    private var entries: [SpotlightItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let needle = trimmed.lowercased()

        let modeItems: [SpotlightItem] = WorkspaceWindowMode.allCases.compactMap { mode in
            guard scope == .all || scope == .roomsAndModes else { return nil }
            if needle.isEmpty {
                return scope == .roomsAndModes ? .windowMode(mode) : nil
            }
            let hay = "\(mode.title) \(mode.shortTitle) \(mode.subtitle) strip opencanvas omniwm tiling libre free".lowercased()
            return hay.contains(needle) ? .windowMode(mode) : nil
        }

        let roomItems: [SpotlightItem] = roomStore.rooms.compactMap { room in
            guard scope == .all || scope == .roomsAndModes else { return nil }
            guard needle.isEmpty || room.matches(needle) || "room rooms scene".contains(needle) else { return nil }
            return .room(room)
        }

        let snippetApps = launcher.launcherCommands() + launcher.loadSnippets(settings: settings)
        let regularApps = appCatalog

        let candidateApps: [LaunchableApp]
        switch scope {
        case .all:
            candidateApps = snippetApps + regularApps
        case .apps:
            candidateApps = regularApps
        case .roomsAndModes:
            candidateApps = []
        case .snippets:
            candidateApps = snippetApps
        }

        let filteredApps: [SpotlightItem] = candidateApps.compactMap { app in
            guard !needle.isEmpty else { return .app(app) }
            let match = app.name.lowercased().contains(needle)
                || app.bundleID.lowercased().contains(needle)
                || app.snippet?.searchText.lowercased().contains(needle) == true
                || matchesLauncherCommand(app, needle: needle)
            return match ? .app(app) : nil
        }

        if !needle.isEmpty {
            return modeItems + roomItems + filteredApps
        }
        switch scope {
        case .all:
            return roomItems.prefix(3).map { $0 } + filteredApps
        case .roomsAndModes:
            return modeItems + roomItems
        case .apps, .snippets:
            return filteredApps
        }
    }

    var body: some View {
        let calcState = LaunchpadCalculator.evaluate(query)
        let visibleItems = calcState == nil ? entries : []

        VStack(spacing: 0) {
            searchBar

            scopeAndModeStrip
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            Divider()

            if let calcState {
                calculatorPanel(for: calcState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(localizedString("No results"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                                SpotlightRow(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    activeMode: canvas.currentWorkspace?.profile.workspaceMode ?? .free
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    activate(item)
                                }
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: selectedIndex) { idx in
                        guard idx < visibleItems.count else { return }
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(visibleItems[idx].id, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            spotlightFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            CompactKeyMonitor { event in
                handleKey(event, items: visibleItems, calcState: calcState)
            }
        )
        .onAppear {
            canvas.refreshCurrentWorkspace()
            launcher.loadAppsAsync(settings: settings) { apps in
                appCatalog = apps
                selectedIndex = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
        .onChange(of: query) { _ in
            selectedIndex = 0
        }
        .onChange(of: scope) { _ in
            selectedIndex = 0
        }
        .onExitCommand {
            LaunchpadOverlayController.shared.hide()
        }
        .alert("Action Result", isPresented: commandFeedbackPresented) {
            Button("OK", role: .cancel) { commandFeedbackMessage = nil }
        } message: {
            Text(commandFeedbackMessage ?? "")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(localizedString("Search apps, rooms, window modes, snippets…"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .focused($searchFocused)
                .onSubmit { handleEnter() }
            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var scopeAndModeStrip: some View {
        HStack(spacing: 6) {
            ForEach(SpotlightScope.allCases) { item in
                let active = scope == item
                Button {
                    scope = item
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(item.title)
                            .font(.system(size: 11, weight: active ? .bold : .medium, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        Capsule()
                            .fill(active ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.06))
                    )
                    .foregroundStyle(active ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)

            if let ws = canvas.currentWorkspace {
                let mode = ws.profile.workspaceMode
                let modeColor = PKStudioPalette.color(for: mode)
                Button {
                    canvas.cycleWorkspaceMode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.symbolName)
                            .font(.system(size: 10, weight: .semibold))
                        Text(mode.shortTitle)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(modeColor.opacity(0.18), in: Capsule())
                    .foregroundStyle(modeColor)
                }
                .buttonStyle(.plain)
                .help(localizedString("Click to cycle window mode (Free → Tiling → Strip)"))
            }
        }
    }

    private var spotlightFooter: some View {
        HStack(spacing: 12) {
            Text("↑↓ \(localizedString("Navigate"))")
            Text("⇥ \(localizedString("Filter"))")
            Text("↵ \(localizedString("Open"))")
            Spacer()
            Button {
                LaunchpadOverlayController.shared.hide()
                SettingsWindowController.shared.showSettings()
            } label: {
                Label(localizedString("Settings"), systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 10.5, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func calculatorPanel(for state: LaunchpadCalculatorState) -> some View {
        switch state {
        case .result(let result):
            VStack(spacing: 8) {
                Text(result.expression)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(result.displayValue)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(localizedString("Press Enter to copy"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                Text(localizedString("Check the expression"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleKey(_ event: NSEvent, items: [SpotlightItem], calcState: LaunchpadCalculatorState?) -> Bool {
        if event.keyCode == 53 {
            if query.isEmpty {
                LaunchpadOverlayController.shared.hide()
            } else {
                query = ""
                searchFocused = true
            }
            return true
        }

        // Tab cycles scope
        if event.keyCode == 48 {
            let all = SpotlightScope.allCases
            if let idx = all.firstIndex(of: scope) {
                scope = all[(idx + 1) % all.count]
            }
            return true
        }

        if case .result(let result)? = calcState {
            if event.keyCode == 36 || event.keyCode == 76 {
                copyToClipboard(result.copyValue)
                LaunchpadOverlayController.shared.hide()
                return true
            }
            return false
        }

        guard !items.isEmpty else { return false }

        switch event.keyCode {
        case 125:
            selectedIndex = min(selectedIndex + 1, items.count - 1)
            return true
        case 126:
            selectedIndex = max(selectedIndex - 1, 0)
            return true
        case 36, 76:
            activate(items[selectedIndex])
            return true
        default:
            return false
        }
    }

    private func handleEnter() {
        let calcState = LaunchpadCalculator.evaluate(query)
        if case .result(let result)? = calcState {
            copyToClipboard(result.copyValue)
            LaunchpadOverlayController.shared.hide()
            return
        }
        let visible = entries
        guard visible.indices.contains(selectedIndex) else { return }
        activate(visible[selectedIndex])
    }

    private func activate(_ item: SpotlightItem) {
        switch item {
        case .app(let app):
            if let message = launcher.launch(app, settings: settings) {
                commandFeedbackMessage = message
                return
            }
            LaunchpadOverlayController.shared.hide()
        case .room(let room):
            LaunchpadOverlayController.shared.hide()
            let claimed = roomStore.claimedWindowIDs(excluding: room.id)
            let keepMonocle = canvas.willTile(room)
            canvas.releaseForRoomActivation(room) { released in
                guard released else { return }
                Task {
                    _ = await RoomEngine().activate(room, claimed: claimed, keepMonocleWindowsVisible: keepMonocle)
                    await MainActor.run { canvas.resumeAfterRoomActivation(room) }
                }
            }
        case .windowMode(let mode):
            canvas.setWorkspaceMode(mode)
            LaunchpadOverlayController.shared.hide()
        }
    }

    private func copyToClipboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    private func matchesLauncherCommand(_ app: LaunchableApp, needle: String) -> Bool {
        switch app.id {
        case LauncherCommand.emptyTrash.rawValue:
            return ["empty trash", "vider corbeille", "trash"].contains { needle.contains($0) || $0.contains(needle) }
        case LauncherCommand.eject.rawValue:
            return ["eject", "éject"].contains { needle.contains($0) || $0.contains(needle) }
        default:
            return false
        }
    }

    private var commandFeedbackPresented: Binding<Bool> {
        Binding(
            get: { commandFeedbackMessage != nil },
            set: { if !$0 { commandFeedbackMessage = nil } }
        )
    }
}

private struct SpotlightRow: View {
    let item: SpotlightItem
    let isSelected: Bool
    let activeMode: WorkspaceWindowMode

    var body: some View {
        HStack(spacing: 12) {
            switch item {
            case .app(let app):
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)

                Text(app.name)
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .lineLimit(1)

                Spacer()

                if let shortcut = app.shortcut {
                    ShortcutKeyBadge(shortcut: shortcut, compact: true)
                }

            case .room(let room):
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(PKStudioPalette.roomsAccent.opacity(0.18))
                    Image(systemName: (room.useSavedFrames && room.hasSavedFrames) ? "mappin.and.ellipse" : "rectangle.3.group.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PKStudioPalette.roomsAccent)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(room.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Text("\(room.windows.count) window(s) · \(room.placementModeSummary)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("Room")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PKStudioPalette.roomsAccent.opacity(0.16), in: Capsule())
                    .foregroundStyle(PKStudioPalette.roomsAccent)

            case .windowMode(let mode):
                let color = PKStudioPalette.color(for: mode)
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.18))
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(mode.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if activeMode == mode {
                    Text(localizedString("Active"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.18), in: Capsule())
                        .foregroundStyle(color)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

private struct CompactKeyMonitor: NSViewRepresentable {
    let handle: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(handle: handle) }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.handle = handle
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var handle: (NSEvent) -> Bool
        private var monitor: Any?

        init(handle: @escaping (NSEvent) -> Bool) { self.handle = handle }

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                self?.handle(event) == true ? nil : event
            }
        }

        func stop() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        deinit { stop() }
    }
}
