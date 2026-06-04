import AppKit
import UniformTypeIdentifiers
import SwiftUI

struct LaunchpadView: View {
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var shortcutTarget: LaunchableApp?
    @State private var backupMessage: String?
    @State private var accessibilityGranted = AXIsProcessTrusted()
    private let launcher = AppLauncherService()
    private let statusTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let apps = filteredApps
        VStack(alignment: .leading, spacing: 16) {
            accessibilityCard
                .padding(.horizontal, 24)
                .padding(.top, 20)

            activationSettings
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Launchpad")
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
        .alert("Settings Backup", isPresented: backupMessagePresented) {
            Button("OK", role: .cancel) {
                backupMessage = nil
            }
        } message: {
            Text(backupMessage ?? "")
        }
        .task(id: settings.recentBundleIDs) { }
        .onReceive(statusTimer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    private var accessibilityCard: some View {
        HStack(spacing: 12) {
            Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accessibilityGranted ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(accessibilityGranted ? "Accessibility Granted" : "Accessibility Required")
                    .font(.headline)
                Text("Keyboard shortcuts need accessibility access to work.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !accessibilityGranted {
                Button("Grant Access") {
                    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                    AXIsProcessTrustedWithOptions(options)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accessibilityGranted ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accessibilityGranted ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var activationSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Launchpad Activation")
                .font(.headline)

            HStack(spacing: 12) {
                Text("Global shortcut")
                    .frame(width: 110, alignment: .leading)

                Picker("", selection: $settings.launchpadShortcut.modifier) {
                    ForEach(ShortcutModifierPreset.allCases) { modifier in
                        Text(modifier.displayName).tag(modifier)
                    }
                }
                .labelsHidden()
                .frame(width: 190)

                TextField("Key", text: launchpadKeyBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)

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

            Divider()

            HStack(spacing: 28) {
                Text("Grid layout")
                    .frame(width: 110, alignment: .leading)

                Stepper(value: $settings.launchpadGridColumns, in: 4...14) {
                    HStack(spacing: 6) {
                        Text("Columns")
                        Text("\(settings.launchpadGridColumns)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $settings.launchpadGridRows, in: 3...10) {
                    HStack(spacing: 6) {
                        Text("Rows")
                        Text("\(settings.launchpadGridRows)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(settings.launchpadGridColumns * settings.launchpadGridRows) applications visible")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            HStack(spacing: 28) {
                Text("Sizing")
                    .frame(width: 110, alignment: .leading)

                Stepper(value: $settings.launchpadIconSize, in: 28...96, step: 4) {
                    HStack(spacing: 6) {
                        Text("Icon size")
                        Text("\(settings.launchpadIconSize)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $settings.launchpadColumnSpacing, in: 4...48, step: 2) {
                    HStack(spacing: 6) {
                        Text("Column gap")
                        Text("\(settings.launchpadColumnSpacing)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $settings.launchpadRowSpacing, in: 4...48, step: 2) {
                    HStack(spacing: 6) {
                        Text("Row gap")
                        Text("\(settings.launchpadRowSpacing)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Text("Navigation")
                    .frame(width: 110, alignment: .leading)

                Picker("", selection: $settings.launchpadGridNavigation) {
                    ForEach(LaunchpadGridNavigation.allCases) { navigation in
                        Text(navigation.title).tag(navigation)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 280)

                Text(settings.launchpadGridNavigation == .horizontalPages
                     ? "Swipe horizontally to move page by page."
                     : "Scroll vertically through all applications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Divider()

            HStack(spacing: 12) {
                Text("Backup")
                    .frame(width: 110, alignment: .leading)

                Button("Export Settings...") {
                    exportSettings()
                }

                Button("Import Settings...") {
                    importSettings()
                }

                Text("Save or restore shortcuts, activation, grid, and navigation settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Divider()

            HStack(spacing: 12) {
                Text("Auto-backup")
                    .frame(width: 110, alignment: .leading)

                Toggle("", isOn: $settings.autoBackupEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)

                if settings.autoBackupEnabled {
                    Button(settings.autoBackupFolder?.lastPathComponent ?? "Choose folder...") {
                        chooseAutoBackupFolder()
                    }

                    if let folder = settings.autoBackupFolder {
                        Text(folder.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                } else {
                    Text("Automatically export settings to a folder on every change.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var launchpadKeyBinding: Binding<String> {
        Binding(
            get: {
                settings.launchpadShortcut.key == "space"
                    ? "Space"
                    : settings.launchpadShortcut.key.uppercased()
            },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !trimmed.isEmpty else { return }
                settings.launchpadShortcut.key = trimmed == "space"
                    ? "space"
                    : String(trimmed.suffix(1))
            }
        )
    }

    private var backupMessagePresented: Binding<Bool> {
        Binding(
            get: { backupMessage != nil },
            set: { if !$0 { backupMessage = nil } }
        )
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PKwindowsManagement-settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try settings.exportBackup().write(to: url, options: .atomic)
            backupMessage = "Settings exported successfully."
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try settings.importBackup(Data(contentsOf: url))
            backupMessage = "Settings imported successfully."
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func chooseAutoBackupFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if let current = settings.autoBackupFolder {
            panel.directoryURL = current
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.autoBackupFolder = url
        settings.performAutoBackup()
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
