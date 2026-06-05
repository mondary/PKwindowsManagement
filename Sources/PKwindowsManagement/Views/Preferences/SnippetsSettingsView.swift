import AppKit
import SwiftUI

struct SnippetsSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedSnippetID: String?

    private let sidebarWidth: CGFloat = 360

    var body: some View {
        snippetListView(
            title: "Scripts",
            subtitle: "Reusable scripts with keyboard shortcuts and Launchpad access.",
            emptyTitle: "No scripts yet",
            emptySubtitle: "Add a script to run commands from Launchpad or a shortcut.",
            iconName: "doc.plaintext",
            makeNewSnippet: {
                SnippetDefinition(title: "New Script", body: "", isEnabled: true)
            },
            filteredSnippets: scriptSnippets,
            selectedSnippetID: $selectedSnippetID,
            settings: settings
        )
        .onAppear { syncSelection() }
        .onChange(of: settings.snippets) { _ in syncSelection() }
    }

    private var scriptSnippets: [SnippetDefinition] {
        settings.snippets.filter { $0.kind == .script }
    }

    private func syncSelection() {
        guard let selectedSnippetID,
              scriptSnippets.contains(where: { $0.id == selectedSnippetID })
        else {
            self.selectedSnippetID = scriptSnippets.first?.id
            return
        }
    }
}

struct URLSnippetsSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedSnippetID: String?

    private let sidebarWidth: CGFloat = 360

    var body: some View {
        snippetListView(
            title: "URLs",
            subtitle: "Reusable URLs with a browser target and keyboard shortcuts.",
            emptyTitle: "No URLs yet",
            emptySubtitle: "Add a URL to open it quickly in the browser of your choice.",
            iconName: "link",
            makeNewSnippet: {
                SnippetDefinition(title: "New URL", urlString: "", browserBundleID: nil, isEnabled: true)
            },
            filteredSnippets: urlSnippets,
            selectedSnippetID: $selectedSnippetID,
            settings: settings
        )
        .onAppear { syncSelection() }
        .onChange(of: settings.snippets) { _ in syncSelection() }
    }

    private var urlSnippets: [SnippetDefinition] {
        settings.snippets.filter { $0.kind == .url }
    }

    private func syncSelection() {
        guard let selectedSnippetID,
              urlSnippets.contains(where: { $0.id == selectedSnippetID })
        else {
            self.selectedSnippetID = urlSnippets.first?.id
            return
        }
    }
}

private func snippetListView(
    title: String,
    subtitle: String,
    emptyTitle: String,
    emptySubtitle: String,
    iconName: String,
    makeNewSnippet: @escaping () -> SnippetDefinition,
    filteredSnippets: [SnippetDefinition],
    selectedSnippetID: Binding<String?>,
    settings: AppSettings
) -> some View {
    HStack(spacing: 0) {
        leftPane(
            title: title,
            subtitle: subtitle,
            emptyTitle: emptyTitle,
            emptySubtitle: emptySubtitle,
            iconName: iconName,
            makeNewSnippet: makeNewSnippet,
            filteredSnippets: filteredSnippets,
            selectedSnippetID: selectedSnippetID,
            settings: settings
        )
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))

        Divider()

        rightPane(
            emptyTitle: emptyTitle,
            emptySubtitle: emptySubtitle,
            iconName: iconName,
            filteredSnippets: filteredSnippets,
            selectedSnippetID: selectedSnippetID,
            settings: settings
        )
    }
}

private func leftPane(
    title: String,
    subtitle: String,
    emptyTitle: String,
    emptySubtitle: String,
    iconName: String,
    makeNewSnippet: @escaping () -> SnippetDefinition,
    filteredSnippets: [SnippetDefinition],
    selectedSnippetID: Binding<String?>,
    settings: AppSettings
) -> some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    let snippet = makeNewSnippet()
                    _ = settings.addSnippet(snippet)
                    selectedSnippetID.wrappedValue = snippet.id
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if filteredSnippets.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(emptyTitle)
                        .font(.headline)
                    Text(emptySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredSnippets) { snippet in
                        snippetRow(snippet: snippet, selectedSnippetID: selectedSnippetID, settings: settings)
                    }
                }
            }
        }
        .padding(24)
    }
}

private func rightPane(
    emptyTitle: String,
    emptySubtitle: String,
    iconName: String,
    filteredSnippets: [SnippetDefinition],
    selectedSnippetID: Binding<String?>,
    settings: AppSettings
) -> some View {
    Group {
        if let snippet = selectedSnippet(for: filteredSnippets, selectedSnippetID: selectedSnippetID.wrappedValue) {
            SnippetEditorView(
                settings: settings,
                snippet: snippet,
                onDelete: {
                    settings.deleteSnippet(snippet)
                    selectedSnippetID.wrappedValue = filteredSnippets.first(where: { $0.id != snippet.id })?.id
                }
            )
            .id(snippet.id)
        } else {
            VStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Select an item")
                    .font(.headline)
                Text(emptySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    .padding(24)
    .background(Color(NSColor.controlBackgroundColor))
}

private func snippetRow(
    snippet: SnippetDefinition,
    selectedSnippetID: Binding<String?>,
    settings: AppSettings
) -> some View {
    let shortcut = settings.launchShortcut(for: snippet.id)
    let isSelected = selectedSnippetID.wrappedValue == snippet.id

    return Button {
        selectedSnippetID.wrappedValue = snippet.id
    } label: {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: snippet.kind == .url ? "link" : "doc.plaintext")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(snippet.title)
                        .font(.body.weight(.medium))
                    if !snippet.isEnabled {
                        Text("Off")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(snippet.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                if let shortcut {
                    ShortcutKeyBadge(shortcut: shortcut, compact: true)
                } else {
                    Text("No shortcut")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("", isOn: enabledBinding(for: snippet, settings: settings))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .contextMenu {
        Button(snippet.isEnabled ? "Disable" : "Enable") {
            settings.setSnippetEnabled(!snippet.isEnabled, for: snippet.id)
        }
        Button("Delete", role: .destructive) {
            settings.deleteSnippet(snippet)
            if selectedSnippetID.wrappedValue == snippet.id {
                selectedSnippetID.wrappedValue = nil
            }
        }
    }
    .opacity(snippet.isEnabled ? 1.0 : 0.65)
}

private func enabledBinding(for snippet: SnippetDefinition, settings: AppSettings) -> Binding<Bool> {
    Binding(
        get: { snippet.isEnabled },
        set: { settings.setSnippetEnabled($0, for: snippet.id) }
    )
}

private func selectedSnippet(for snippets: [SnippetDefinition], selectedSnippetID: String?) -> SnippetDefinition? {
    guard let selectedSnippetID else { return snippets.first }
    return snippets.first(where: { $0.id == selectedSnippetID }) ?? snippets.first
}

private struct SnippetEditorView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    let snippet: SnippetDefinition
    var onDelete: (() -> Void)? = nil

    @State private var title: String
    @State private var bodyText: String
    @State private var urlString: String
    @State private var browserBundleID: String?
    @State private var shortcutEnabled: Bool
    @State private var shortcut: KeyboardShortcutSetting

    init(settings: AppSettings, snippet: SnippetDefinition, onDelete: (() -> Void)? = nil) {
        self.settings = settings
        self.snippet = snippet
        self.onDelete = onDelete
        _title = State(initialValue: snippet.title)
        _bodyText = State(initialValue: snippet.body)
        _urlString = State(initialValue: snippet.urlString)
        _browserBundleID = State(initialValue: snippet.browserBundleID)
        let existing = settings.launchShortcut(for: snippet.id)
        _shortcutEnabled = State(initialValue: existing != nil)
        _shortcut = State(initialValue: existing ?? .init(key: "s", modifier: .command))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3.weight(.medium))

            editorFields

            VStack(alignment: .leading, spacing: 12) {
                Text("Shortcut")
                    .font(.subheadline.weight(.medium))

                Toggle("Use keyboard shortcut", isOn: $shortcutEnabled)
                    .toggleStyle(.switch)

                if shortcutEnabled {
                    ShortcutRecorderField(
                        shortcut: $shortcut,
                        modifierWidth: 190,
                        keyWidth: 90,
                        recordWidth: 76
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                if let onDelete {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }

                Spacer()

                Button("Cancel", role: .cancel) {
                    dismiss()
                }

                Button("Save") {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultTitle : title
                    let updated = makeUpdatedSnippet(title: trimmedTitle)
                    settings.updateSnippet(updated)
                    if shortcutEnabled {
                        settings.setLaunchShortcut(shortcut, for: updated.id)
                    } else {
                        settings.setLaunchShortcut(nil, for: updated.id)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 860, minHeight: 700, alignment: .topLeading)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var editorFields: some View {
        switch snippet.kind {
        case .script:
            VStack(alignment: .leading, spacing: 8) {
                Text("Script")
                    .font(.subheadline.weight(.medium))
                TextEditor(text: $bodyText)
                    .font(.body.monospaced())
                    .frame(minHeight: 360)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
            }
        case .url:
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL")
                        .font(.subheadline.weight(.medium))
                    TextField("https://example.com", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Browser")
                        .font(.subheadline.weight(.medium))
                    Picker("", selection: $browserBundleID) {
                        Text("Default Browser").tag(Optional<String>.none)
                        ForEach(SnippetBrowserTarget.allCases.filter { $0 != .defaultBrowser }) { browser in
                            Text(browser.title).tag(browser.bundleIdentifier)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snippet.kind == .script ? "Script Editor" : "URL Editor")
                .font(.title3.weight(.semibold))
            Text(snippet.kind == .script ? "Use this to edit the script and shortcut." : "Use this to edit the URL, browser target, and shortcut.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var defaultTitle: String {
        switch snippet.kind {
        case .script: "New Script"
        case .url: "New URL"
        }
    }

    private func makeUpdatedSnippet(title: String) -> SnippetDefinition {
        switch snippet.kind {
        case .script:
            return SnippetDefinition(
                id: snippet.id,
                title: title,
                body: bodyText,
                isEnabled: snippet.isEnabled
            )
        case .url:
            return SnippetDefinition(
                id: snippet.id,
                title: title,
                urlString: urlString,
                browserBundleID: browserBundleID,
                isEnabled: snippet.isEnabled
            )
        }
    }
}
