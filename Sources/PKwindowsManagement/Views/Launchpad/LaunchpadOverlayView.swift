import AppKit
import SwiftUI

struct LaunchpadOverlayView: View {
    @ObservedObject var settings: AppSettings
    let displayID: CGDirectDisplayID?
    @State private var query = ""
    @State private var selectedAppID: String?
    @State private var shortcutTarget: LaunchableApp?
    @State private var uninstallTarget: LaunchableApp?
    @State private var uninstallError: String?
    @State private var appCatalogRevision = 0
    @State private var appCatalog: [LaunchableApp] = []
    @State private var currentPage = 0
    @State private var scrollAccumulator: CGFloat = 0
    @State private var lastScrollDate = Date.distantPast
    @FocusState private var searchFocused: Bool
    private let launcher = AppLauncherService()

    var body: some View {
        let calculationState = LaunchpadCalculator.evaluate(query)
        let apps = filteredApps
        let gridConfiguration = settings.launchpadGridConfiguration(for: displayID)
        GeometryReader { geometry in
            let metrics = gridMetrics(for: geometry.size, configuration: gridConfiguration)
            ZStack {
                VStack(spacing: 24) {
                    topBar
                        .padding(.horizontal, 42)
                        .padding(.top, 34)

                    searchField

                    if let calculationState {
                        calculatorPanel(for: calculationState)
                            .padding(.horizontal, 42)
                            .padding(.top, 8)
                    } else {
                        gridContent(apps: apps, metrics: metrics)
                    }

                    Spacer(minLength: 0)

                    if calculationState == nil {
                        dockStrip(apps: Array(appCatalog.prefix(16)))
                            .padding(.bottom, 28)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background {
                LaunchpadKeyEventMonitor { event in
                    guard shortcutTarget == nil, uninstallTarget == nil, uninstallError == nil else { return false }
                    return handleKeyEvent(event, apps: apps, configuration: gridConfiguration, calculationState: calculationState)
                }
            }
        }
        .onAppear {
            reloadAppCatalog()
            selectFirstApp()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                searchFocused = true
            }
        }
        .onChange(of: settings.launchShortcuts) { _ in
            reloadAppCatalog()
            selectFirstApp()
        }
        .onChange(of: settings.snippets) { _ in
            reloadAppCatalog()
            selectFirstApp()
        }
        .onChange(of: settings.launchpadAppSortMode) { _ in
            reloadAppCatalog()
            selectFirstApp()
        }
        .onChange(of: query) { _ in
            currentPage = 0
            selectFirstApp()
        }
        .onExitCommand {
            LaunchpadOverlayController.shared.hide()
        }
        .sheet(item: $shortcutTarget) { app in
            LaunchShortcutEditor(app: app, settings: settings)
                .frame(width: 420, height: 220)
        }
        .alert(
            "Move \(uninstallTarget?.name ?? "Application") to Trash?",
            isPresented: uninstallConfirmationPresented
        ) {
            Button("Cancel", role: .cancel) {
                uninstallTarget = nil
            }
            Button("Move to Trash", role: .destructive) {
                moveTargetToTrash()
            }
        } message: {
            Text("The application will be removed from its Applications folder.")
        }
        .alert(
            "Unable to Move Application",
            isPresented: uninstallErrorPresented
        ) {
            Button("OK", role: .cancel) {
                uninstallError = nil
            }
        } message: {
            Text(uninstallError ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                LaunchpadOverlayController.shared.openSettings()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.68))
            .background(.white.opacity(0.1), in: Circle())
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            ZStack(alignment: .leading) {
                if query.isEmpty {
                    Text("Search")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .allowsHitTesting(false)
                }
                TextField("", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .focused($searchFocused)
            }
        }
        .foregroundStyle(.white)
        .tint(.white)
        .padding(.horizontal, 14)
        .frame(width: 390, height: 38)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func calculatorPanel(for state: LaunchpadCalculatorState) -> some View {
        switch state {
        case .result(let result):
            VStack(alignment: .center, spacing: 10) {
                Text(result.expression)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(result.displayValue)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Press Enter to copy the result.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: 640, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
        case .error(let message):
            VStack(alignment: .center, spacing: 10) {
                Text("Calculator")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(message)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Check the expression or the units.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: 640, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
        }
    }

    private func dockStrip(apps: [LaunchableApp]) -> some View {
        HStack(spacing: 14) {
            ForEach(apps.prefix(14)) { app in
                Button {
                    launch(app)
                } label: {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    appContextMenu(for: app)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func gridContent(apps: [LaunchableApp], metrics: LaunchpadGridMetrics) -> some View {
        switch settings.launchpadGridNavigation {
        case .vertical:
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    appGrid(apps: apps, metrics: metrics)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.vertical, metrics.verticalPadding)
                }
                .scrollIndicators(.visible)
                .frame(height: metrics.viewportHeight)
                .onChange(of: selectedAppID) { id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        case .horizontalPages:
            let pages = appPages(apps, configuration: settings.launchpadGridConfiguration(for: displayID))
            VStack(spacing: 10) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(Array(pages.enumerated()), id: \.offset) { page, pageApps in
                                VStack {
                                    appGrid(apps: pageApps, metrics: metrics)
                                        .padding(.horizontal, metrics.horizontalPadding)
                                        .padding(.top, metrics.verticalPadding)
                                    Spacer(minLength: 0)
                                }
                                .frame(width: metrics.viewportWidth, height: metrics.viewportHeight)
                                .id(page)
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                    .frame(width: metrics.viewportWidth, height: metrics.viewportHeight)
                    .simultaneousGesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    changePage(direction: value.translation.width < 0 ? 1 : -1, pageCount: pages.count)
                                }
                        )
                    .onChange(of: currentPage) { page in
                        withAnimation(.easeInOut(duration: 0.22)) {
                            proxy.scrollTo(page, anchor: .leading)
                        }
                    }
                }

                pageIndicator(pageCount: pages.count)
            }
        }
    }

    private func appGrid(apps: [LaunchableApp], metrics: LaunchpadGridMetrics) -> some View {
        LazyVGrid(columns: metrics.columns, spacing: metrics.rowSpacing) {
            ForEach(apps) { app in
                Button {
                    launch(app)
                } label: {
                    OverlayAppTile(
                        app: app,
                        isSelected: app.id == selectedAppID,
                        tileSize: metrics.tileSize,
                        iconSize: metrics.iconSize
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    appContextMenu(for: app)
                }
                .id(app.id)
            }
        }
    }

    private func pageIndicator(pageCount: Int) -> some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { page in
                Button {
                    currentPage = page
                } label: {
                    Circle()
                        .fill(.white.opacity(page == currentPage ? 0.9 : 0.3))
                        .frame(width: 7, height: 7)
                        .frame(width: 20, height: 20)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 20)
    }

    private func appPages(_ apps: [LaunchableApp], configuration: LaunchpadGridConfiguration) -> [[LaunchableApp]] {
        let pageSize = max(1, configuration.columns * configuration.rows)
        return stride(from: 0, to: apps.count, by: pageSize).map { start in
            Array(apps[start..<min(start + pageSize, apps.count)])
        }
    }

    private func changePage(direction: Int, pageCount: Int) {
        guard pageCount > 0 else { return }
        let nextPage = min(max(currentPage + direction, 0), pageCount - 1)
        guard nextPage != currentPage else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            currentPage = nextPage
        }
    }

    private func gridMetrics(for size: CGSize, configuration: LaunchpadGridConfiguration) -> LaunchpadGridMetrics {
        let horizontalInset = max(54, size.width * 0.1) * 2
        let viewportHeight = max(300, size.height - 260)
        let columnSpacing = CGFloat(settings.launchpadColumnSpacing)
        let rowSpacing = CGFloat(settings.launchpadRowSpacing)
        let verticalPadding = max(6, min(20, rowSpacing))
        let availableWidth = size.width - horizontalInset - columnSpacing * CGFloat(configuration.columns - 1)
        let availableHeight = viewportHeight - verticalPadding * 2 - rowSpacing * CGFloat(configuration.rows - 1)
        let tileWidth = availableWidth / CGFloat(configuration.columns)
        let tileHeight = availableHeight / CGFloat(configuration.rows)
        let iconSize = CGFloat(settings.launchpadIconSize)

        return LaunchpadGridMetrics(
            columns: Array(
                repeating: GridItem(.flexible(minimum: tileWidth, maximum: tileWidth + 20), spacing: columnSpacing),
                count: configuration.columns
            ),
            rowSpacing: rowSpacing,
            horizontalPadding: horizontalInset / 2,
            verticalPadding: verticalPadding,
            viewportWidth: size.width,
            viewportHeight: viewportHeight,
            tileSize: CGSize(width: tileWidth, height: tileHeight),
            iconSize: iconSize
        )
    }

    private func selectFirstApp() {
        selectedAppID = LaunchpadCalculator.evaluate(query) == nil ? filteredApps.first?.id : nil
    }

    private func handleKeyEvent(_ event: NSEvent, apps: [LaunchableApp], configuration: LaunchpadGridConfiguration, calculationState: LaunchpadCalculatorState?) -> Bool {
        if case .result(let result)? = calculationState, event.keyCode == 36 || event.keyCode == 76 {
            copyToClipboard(result.copyValue)
            LaunchpadOverlayController.shared.hide()
            return true
        }

        if calculationState != nil {
            if event.keyCode == 53 {
                if query.isEmpty {
                    LaunchpadOverlayController.shared.hide()
                } else {
                    query = ""
                    searchFocused = true
                }
                return true
            }
            return false
        }

        if event.type == .scrollWheel {
            return handleScrollEvent(event, apps: apps, configuration: configuration)
        }

        if event.keyCode == 43, event.modifierFlags.contains(.command) {
            LaunchpadOverlayController.shared.openSettings()
            return true
        }

        if event.keyCode == 53 {
            if query.isEmpty {
                LaunchpadOverlayController.shared.hide()
            } else {
                query = ""
                searchFocused = true
            }
            return true
        }

        guard !apps.isEmpty else { return false }

        if event.keyCode == 36 || event.keyCode == 76 {
            launch(selectedApp(in: apps) ?? apps[0])
            return true
        }

        let movement: Int
        switch event.keyCode {
        case 123: movement = -1
        case 124: movement = 1
        case 125: movement = configuration.columns
        case 126: movement = -configuration.columns
        default: return false
        }

        let currentIndex = apps.firstIndex { $0.id == selectedAppID } ?? 0
        let nextIndex = min(max(currentIndex + movement, 0), apps.count - 1)
        selectedAppID = apps[nextIndex].id
        if settings.launchpadGridNavigation == .horizontalPages {
            currentPage = nextIndex / max(1, configuration.columns * configuration.rows)
        }
        return true
    }

    private func handleScrollEvent(_ event: NSEvent, apps: [LaunchableApp], configuration: LaunchpadGridConfiguration) -> Bool {
        guard !apps.isEmpty else { return false }
        guard settings.launchpadGridNavigation == .horizontalPages else { return false }

        let now = Date()
        if now.timeIntervalSince(lastScrollDate) > 0.3 {
            scrollAccumulator = 0
        }
        lastScrollDate = now

        let delta: CGFloat = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX
            : event.scrollingDeltaY

        scrollAccumulator += delta
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 12 : 1
        guard abs(scrollAccumulator) >= threshold else { return true }

        let direction = scrollAccumulator > 0 ? -1 : 1
        scrollAccumulator = 0

        changePage(direction: direction, pageCount: appPages(apps, configuration: configuration).count)
        selectFirstAppOnCurrentPage(apps, configuration: configuration)
        return true
    }

    private func moveSelection(by movement: Int, apps: [LaunchableApp]) {
        let currentIndex = apps.firstIndex { $0.id == selectedAppID } ?? 0
        let nextIndex = min(max(currentIndex + movement, 0), apps.count - 1)
        selectedAppID = apps[nextIndex].id
    }

    private func selectFirstAppOnCurrentPage(_ apps: [LaunchableApp], configuration: LaunchpadGridConfiguration) {
        let pageSize = max(1, configuration.columns * configuration.rows)
        let index = min(currentPage * pageSize, apps.count - 1)
        selectedAppID = apps[index].id
    }

    private func selectedApp(in apps: [LaunchableApp]) -> LaunchableApp? {
        apps.first { $0.id == selectedAppID }
    }

    private func launch(_ app: LaunchableApp) {
        launcher.launch(app, settings: settings)
        LaunchpadOverlayController.shared.hide()
    }

    private func copyToClipboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    @ViewBuilder
    private func appContextMenu(for app: LaunchableApp) -> some View {
        Button(app.shortcut == nil ? "Assign Shortcut..." : "Edit Shortcut...") {
            shortcutTarget = app
        }

        if launcher.canUninstall(app) {
            Divider()
            Button("Move to Trash...", role: .destructive) {
                uninstallTarget = app
            }
        }
    }

    private var uninstallConfirmationPresented: Binding<Bool> {
        Binding(
            get: { uninstallTarget != nil },
            set: { if !$0 { uninstallTarget = nil } }
        )
    }

    private var uninstallErrorPresented: Binding<Bool> {
        Binding(
            get: { uninstallError != nil },
            set: { if !$0 { uninstallError = nil } }
        )
    }

    private func moveTargetToTrash() {
        guard let app = uninstallTarget else { return }
        uninstallTarget = nil
        do {
            try launcher.moveToTrash(app)
            appCatalogRevision += 1
            reloadAppCatalog()
            selectFirstApp()
        } catch {
            uninstallError = error.localizedDescription
        }
    }

    private func reloadAppCatalog() {
        appCatalog = launcher.loadApps(settings: settings)
    }

    private var filteredApps: [LaunchableApp] {
        _ = appCatalogRevision
        let all = launcher.launcherCommands() + launcher.loadSnippets(settings: settings) + appCatalog
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let needle = trimmed.lowercased()
        return all.filter {
            $0.name.lowercased().contains(needle)
            || $0.bundleID.lowercased().contains(needle)
            || $0.snippet?.searchText.lowercased().contains(needle) == true
            || matchesLauncherCommand($0, needle: needle)
        }
    }

    private func matchesLauncherCommand(_ app: LaunchableApp, needle: String) -> Bool {
        switch app.id {
        case LauncherCommand.emptyTrash.rawValue:
            return ["empty trash", "vider corbeille", "vider corbeil", "trash"].contains { needle.contains($0) || $0.contains(needle) }
        case LauncherCommand.eject.rawValue:
            return ["eject", "éject", "ejecter"].contains { needle.contains($0) || $0.contains(needle) }
        default:
            return false
        }
    }

    private func shortcutLabel(for shortcut: KeyboardShortcutSetting?) -> String {
        guard let shortcut else { return "" }
        return "\(shortcut.modifier.symbolPrefix) \(shortcut.key.uppercased())"
    }
}

private struct OverlayAppTile: View {
    let app: LaunchableApp
    let isSelected: Bool
    let tileSize: CGSize
    let iconSize: CGFloat

    var body: some View {
        let displayIconSize = app.launchpadSymbolName == nil ? iconSize : max(22, iconSize * 0.78)
        VStack(spacing: max(4, min(9, tileSize.height * 0.08))) {
            ZStack(alignment: .bottomTrailing) {
                if let symbolName = app.launchpadSymbolName {
                    Image(systemName: symbolName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.white)
                        .frame(width: displayIconSize, height: displayIconSize)
                } else {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                }
                if let shortcut = app.shortcut {
                    ShortcutKeyBadge(shortcut: shortcut, compact: iconSize < 52)
                        .offset(x: displayIconSize * 0.18, y: displayIconSize * 0.12)
                }
            }
            .frame(width: tileSize.width, height: displayIconSize + 8)
            Text(app.name)
                .font(.system(size: iconSize < 48 ? 10 : 12, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(tileSize.height < 90 ? 1 : 2)
                .frame(width: tileSize.width, alignment: .top)
        }
        .frame(width: tileSize.width, height: tileSize.height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(isSelected ? 0.16 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(isSelected ? 0.32 : 0), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.04 : 1)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

private struct LaunchpadGridMetrics {
    let columns: [GridItem]
    let rowSpacing: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let viewportWidth: CGFloat
    let viewportHeight: CGFloat
    let tileSize: CGSize
    let iconSize: CGFloat
}

private struct LaunchpadKeyEventMonitor: NSViewRepresentable {
    let handle: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(handle: handle)
    }

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

        init(handle: @escaping (NSEvent) -> Bool) {
            self.handle = handle
        }

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak self] event in
                self?.handle(event) == true ? nil : event
            }
        }

        func stop() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        deinit {
            stop()
        }
    }
}
