import SwiftUI

struct LaunchpadOverlayView: View {
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var selectedAppID: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    private let launcher = AppLauncherService()

    var body: some View {
        let apps = filteredApps
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 24) {
                    topBar
                        .padding(.horizontal, 42)
                        .padding(.top, 34)

                    searchField

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: gridColumns(for: geometry.size), spacing: 28) {
                                ForEach(apps) { app in
                                    Button {
                                        launch(app)
                                    } label: {
                                        OverlayAppTile(app: app, isSelected: app.id == selectedAppID)
                                    }
                                    .buttonStyle(.plain)
                                    .id(app.id)
                                }
                            }
                            .padding(.horizontal, max(54, geometry.size.width * 0.1))
                            .padding(.top, 34)
                            .padding(.bottom, 126)
                        }
                        .onChange(of: selectedAppID) { id in
                            guard let id else { return }
                            withAnimation(.easeOut(duration: 0.12)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }

                VStack {
                    Spacer()
                    dockStrip(apps: Array(launcher.loadApps(settings: settings).prefix(16)))
                        .padding(.bottom, 28)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background {
                LaunchpadKeyEventMonitor { event in
                    handleKeyEvent(event, apps: apps, columnCount: gridColumns(for: geometry.size).count)
                }
            }
        }
        .onAppear {
            selectFirstApp()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                searchFocused = true
            }
        }
        .onChange(of: query) { _ in
            selectFirstApp()
        }
        .onExitCommand {
            LaunchpadOverlayController.shared.hide()
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                LaunchpadOverlayController.shared.hide()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
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
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .focused($searchFocused)
        }
        .padding(.horizontal, 14)
        .frame(width: 390, height: 38)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
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

    private func gridColumns(for size: CGSize) -> [GridItem] {
        let horizontalInset = max(54, size.width * 0.1) * 2
        let availableWidth = max(420, size.width - horizontalInset)
        let itemWidth: CGFloat = 112
        let count = max(4, min(10, Int(availableWidth / itemWidth)))
        return Array(repeating: GridItem(.fixed(104), spacing: 34), count: count)
    }

    private func selectFirstApp() {
        selectedAppID = filteredApps.first?.id
    }

    private func handleKeyEvent(_ event: NSEvent, apps: [LaunchableApp], columnCount: Int) -> Bool {
        guard !apps.isEmpty else { return false }

        if event.keyCode == 36 || event.keyCode == 76 {
            launch(selectedApp(in: apps) ?? apps[0])
            return true
        }

        let movement: Int
        switch event.keyCode {
        case 123: movement = -1
        case 124: movement = 1
        case 125: movement = columnCount
        case 126: movement = -columnCount
        default: return false
        }

        let currentIndex = apps.firstIndex { $0.id == selectedAppID } ?? 0
        let nextIndex = min(max(currentIndex + movement, 0), apps.count - 1)
        selectedAppID = apps[nextIndex].id
        return true
    }

    private func selectedApp(in apps: [LaunchableApp]) -> LaunchableApp? {
        apps.first { $0.id == selectedAppID }
    }

    private func launch(_ app: LaunchableApp) {
        launcher.launch(app, settings: settings)
        LaunchpadOverlayController.shared.hide()
    }

    private var filteredApps: [LaunchableApp] {
        let all = launcher.launcherCommands() + launcher.loadApps(settings: settings)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let needle = trimmed.lowercased()
        return all.filter {
            $0.name.lowercased().contains(needle)
            || $0.bundleID.lowercased().contains(needle)
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

    var body: some View {
        VStack(spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                if let shortcut = app.shortcut {
                    Text(shortcut.modifier.symbolPrefix + shortcut.key.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.78), in: Capsule())
                        .foregroundStyle(.white)
                        .offset(x: 11, y: 7)
                }
            }
            .frame(width: 80, height: 80)
            Text(app.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 104, height: 31, alignment: .top)
        }
        .frame(width: 104, height: 116)
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
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
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
