import SwiftUI

struct LaunchpadView: View {
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var shortcutTarget: LaunchableApp?
    private let launcher = AppLauncherService()

    var body: some View {
        let apps = filteredApps
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Launchpad")
                    .font(.title2.weight(.semibold))
                TextField("Search apps or recent launches", text: $query)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14)], spacing: 14) {
                    ForEach(apps) { app in
                        VStack(spacing: 8) {
                            Button {
                                launcher.launch(app, settings: settings)
                            } label: {
                                LaunchpadAppTile(app: app)
                            }
                            .buttonStyle(.plain)

                            Button(app.shortcut == nil ? "Assign shortcut" : shortcutLabel(for: app.shortcut)) {
                                shortcutTarget = app
                            }
                            .font(.system(size: 11, weight: .semibold))
                        }
                    }
                }
                .padding(24)
            }
        }
        .sheet(item: $shortcutTarget) { app in
            LaunchShortcutEditor(app: app, settings: settings)
                .frame(width: 420, height: 220)
        }
        .task(id: settings.recentBundleIDs) { }
    }

    private var filteredApps: [LaunchableApp] {
        let all = launcher.launcherCommands() + launcher.loadApps(settings: settings)
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return all }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.filter {
            $0.name.lowercased().contains(needle) || $0.bundleID.lowercased().contains(needle) || matchesLauncherCommand($0, needle: needle)
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
        guard let shortcut else { return "Assign shortcut" }
        return "\(shortcut.modifier.symbolPrefix) \(shortcut.key.uppercased())"
    }
}

struct LaunchShortcutEditor: View {
    let app: LaunchableApp
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var key: String
    @State private var modifier: ShortcutModifierPreset

    init(app: LaunchableApp, settings: AppSettings) {
        self.app = app
        self.settings = settings
        _key = State(initialValue: settings.launchShortcut(for: app.bundleID)?.key ?? "")
        _modifier = State(initialValue: settings.launchShortcut(for: app.bundleID)?.modifier ?? .command)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading) {
                    Text(app.name).font(.headline)
                    Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                }
            }

            Picker("Modifier", selection: $modifier) {
                ForEach(ShortcutModifierPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            TextField("Key", text: $key)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Clear") {
                    settings.setLaunchShortcut(nil, for: app.bundleID)
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    settings.setLaunchShortcut(.init(key: String(trimmed.suffix(1)).lowercased(), modifier: modifier), for: app.bundleID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}

private struct LaunchpadAppTile: View {
    let app: LaunchableApp

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                if let shortcut = app.shortcut {
                    ShortcutKeyBadge(shortcut: shortcut, compact: true)
                        .offset(x: 8, y: 8)
                }
            }
            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}
