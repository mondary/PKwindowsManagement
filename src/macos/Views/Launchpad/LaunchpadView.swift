import AppKit
import SwiftUI

struct LaunchpadView: View {
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var shortcutTarget: LaunchableApp?
    @State private var commandFeedbackMessage: String?
    private let launcher = AppLauncherService()

    var body: some View {
        let apps = filteredApps
        VStack(alignment: .leading, spacing: 16) {
            activationSettings
                .padding(.horizontal, 24)
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text("Applications")
                    .font(.title2.weight(.semibold))
                TextField("Search apps or recent launches", text: $query)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 24)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14)], spacing: 14) {
                    ForEach(apps) { app in
                        VStack(spacing: 8) {
                            Button {
                                commandFeedbackMessage = launcher.launch(app, settings: settings)
                            } label: {
                                LaunchpadAppTile(app: app)
                            }
                            .buttonStyle(.plain)

                            Button(app.shortcut == nil ? localizedString("Assign shortcut") : shortcutLabel(for: app.shortcut)) {
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
        .alert("Action Result", isPresented: commandFeedbackPresented) {
            Button("OK", role: .cancel) {
                commandFeedbackMessage = nil
            }
        } message: {
            Text(commandFeedbackMessage ?? "")
        }
        .task(id: settings.recentBundleIDs) { }
    }

    private var activationSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Launchpad Activation")
                .font(.headline)

            HStack(spacing: 12) {
                Text("Global shortcut")
                    .frame(width: 110, alignment: .leading)

                ShortcutRecorderField(
                    shortcut: $settings.launchpadShortcut,
                    modifierWidth: 190,
                    keyWidth: 100,
                    recordWidth: 76
                )

                ShortcutKeyBadge(shortcut: settings.launchpadShortcut, compact: true)

                Spacer()
            }

            HStack(spacing: 12) {
                Text("Hot corner")
                    .frame(width: 110, alignment: .leading)

                Picker("", selection: $settings.launchpadHotCorner) {
                    ForEach(LaunchpadHotCorner.allCases) { corner in
                        Text(corner.title).tag(corner)
                    }
                }
                .labelsHidden()
                .frame(width: 190)

                Text("Move pointer into selected corner to open Launchpad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            HStack(spacing: 12) {
                Text("Style")
                    .frame(width: 110, alignment: .leading)

                Picker("", selection: $settings.launchpadStyle) {
                    ForEach(LaunchpadStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .labelsHidden()
                .frame(width: 190)

                Text("Compact shows a centered Spotlight-style window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if settings.launchpadStyle == .compact {
                HStack(spacing: 12) {
                    Text("Theme")
                        .frame(width: 110, alignment: .leading)

                    Picker("", selection: $settings.compactLaunchpadTheme) {
                        ForEach(CompactLaunchpadTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)

                    Spacer()
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var filteredApps: [LaunchableApp] {
        let all = launcher.launcherCommands() + launcher.loadSnippets(settings: settings) + launcher.loadApps(settings: settings)
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return all }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
        guard let shortcut else { return localizedString("Assign shortcut") }
        return "\(shortcut.modifier.symbolPrefix) \(shortcut.keyDisplayName)"
    }

    private var commandFeedbackPresented: Binding<Bool> {
        Binding(
            get: { commandFeedbackMessage != nil },
            set: { if !$0 { commandFeedbackMessage = nil } }
        )
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

            ShortcutRecorderField(
                shortcut: shortcutBinding,
                modifierWidth: 190,
                keyWidth: 100,
                recordWidth: 76
            )

            HStack {
                Button("Clear") {
                    settings.setLaunchShortcut(nil, for: app.bundleID)
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    let normalized = normalizedKey(key)
                    guard !normalized.isEmpty else { return }
                    settings.setLaunchShortcut(.init(key: normalized, modifier: modifier), for: app.bundleID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private var shortcutBinding: Binding<KeyboardShortcutSetting> {
        Binding(
            get: {
                KeyboardShortcutSetting(
                    key: normalizedKey(key),
                    modifier: modifier
                )
            },
            set: { shortcut in
                key = shortcut.key
                modifier = shortcut.modifier
            }
        )
    }

    private func normalizedKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.caseInsensitiveCompare("space") == .orderedSame
            || trimmed.caseInsensitiveCompare("espace") == .orderedSame {
            return "space"
        }
        return String(trimmed.suffix(1)).lowercased()
    }

    private func displayKey(_ value: String) -> String {
        value == "space" ? localizedString("Space") : value.uppercased()
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
