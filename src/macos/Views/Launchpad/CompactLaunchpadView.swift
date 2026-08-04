import AppKit
import SwiftUI

struct CompactLaunchpadRootView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        CompactLaunchpadView(settings: settings)
            .environment(\.locale, settings.appLanguage.locale)
            .id(settings.appLanguage)
    }
}

struct CompactLaunchpadView: View {
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var appCatalog: [LaunchableApp] = []
    @State private var commandFeedbackMessage: String?
    @FocusState private var searchFocused: Bool
    private let launcher = AppLauncherService()

    private var apps: [LaunchableApp] {
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

    var body: some View {
        let calcState = LaunchpadCalculator.evaluate(query)
        let visibleApps = calcState == nil ? apps : []

        VStack(spacing: 0) {
            searchBar

            Divider()

            if let calcState {
                calculatorPanel(for: calcState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleApps.isEmpty {
                Text("No results")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(visibleApps.enumerated()), id: \.element.id) { index, app in
                                CompactAppRow(app: app, isSelected: index == selectedIndex)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        launch(app)
                                    }
                                    .id(app.id)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: selectedIndex) { idx in
                        guard idx < visibleApps.count else { return }
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(visibleApps[idx].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            CompactKeyMonitor { event in
                handleKey(event, apps: visibleApps, calcState: calcState)
            }
        )
        .onAppear {
            appCatalog = launcher.loadApps(settings: settings)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
        .onChange(of: query) { _ in
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
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search apps, commands, snippets…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .medium))
                .focused($searchFocused)
                .onSubmit { handleEnter() }
            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
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
                Text("Press Enter to copy")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                Text("Check the expression")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleKey(_ event: NSEvent, apps: [LaunchableApp], calcState: LaunchpadCalculatorState?) -> Bool {
        if event.keyCode == 53 {
            if query.isEmpty {
                LaunchpadOverlayController.shared.hide()
            } else {
                query = ""
                searchFocused = true
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

        guard !apps.isEmpty else { return false }

        switch event.keyCode {
        case 125:
            selectedIndex = min(selectedIndex + 1, apps.count - 1)
            return true
        case 126:
            selectedIndex = max(selectedIndex - 1, 0)
            return true
        case 36, 76:
            launch(apps[selectedIndex])
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
        guard !apps.isEmpty else { return }
        launch(apps[selectedIndex])
    }

    private func launch(_ app: LaunchableApp) {
        if let message = launcher.launch(app, settings: settings) {
            commandFeedbackMessage = message
            return
        }
        LaunchpadOverlayController.shared.hide()
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

private struct CompactAppRow: View {
    let app: LaunchableApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)

            Text(app.name)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)

            Spacer()

            if let shortcut = app.shortcut {
                ShortcutKeyBadge(shortcut: shortcut, compact: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
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
