import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var backupMessage: String?
    @State private var accessibilityGranted = AXIsProcessTrusted()
    private let statusTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                languageSection
                accessibilitySection
                backupSection
                autoBackupSection
            }
            .padding(24)
        }
        .alert("Settings Backup", isPresented: backupMessagePresented) {
            Button("OK", role: .cancel) { backupMessage = nil }
        } message: {
            Text(backupMessage ?? "")
        }
        .onReceive(statusTimer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Language")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Application language", selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .frame(width: 240)

                Text("The interface language changes immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accessibility")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accessibilityGranted ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedString(accessibilityGranted ? "Accessibility Granted" : "Accessibility Required"))
                        .font(.subheadline.weight(.medium))
                    Text("Keyboard shortcuts need accessibility access to control windows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    requestAccess()
                } label: {
                    Label(accessibilityGranted ? localizedString("Re-request Access") : localizedString("Grant Access"), systemImage: "hand.raised.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    openAccessibilitySystemSettings()
                } label: {
                    Label(localizedString("Open System Settings"), systemImage: "gearshape")
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
    }

    private func requestAccess() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
        }
    }

    private func openAccessibilitySystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backup")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    exportSettings()
                } label: {
                    Label("Export Settings...", systemImage: "square.and.arrow.up")
                }

                Button {
                    importSettings()
                } label: {
                    Label("Import Settings...", systemImage: "square.and.arrow.down")
                }

                Spacer()

                Text("Save or restore shortcuts, activation, grid, and navigation settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var autoBackupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Auto-backup")
                .font(.headline)

            Toggle("Enable automatic backup", isOn: $settings.autoBackupEnabled)
                .toggleStyle(.switch)

            if settings.autoBackupEnabled {
                HStack(spacing: 12) {
                    Button {
                        chooseAutoBackupFolder()
                    } label: {
                        Label(settings.autoBackupFolder?.lastPathComponent ?? "Choose folder...", systemImage: "folder")
                    }

                    if let folder = settings.autoBackupFolder {
                        Text(folder.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()
                }

                Text("A timestamped JSON backup is exported to this folder on every settings change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
            backupMessage = localizedString("Settings exported successfully.")
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
            backupMessage = localizedString("Settings imported successfully.")
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
}
