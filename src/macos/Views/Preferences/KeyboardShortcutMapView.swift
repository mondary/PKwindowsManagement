import SwiftUI

/// Carte clavier des raccourcis de fenêtres : chaque touche montre l'icône de sa
/// position et son rappel de raccourci. La carte suit les liaisons courantes.
struct KeyboardShortcutMapView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("Keyboard map"))
                .font(.headline)
            Text(localizedString("Every key shows its window placement and shortcut. The map follows your current shortcuts."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 5) {
                ForEach(WindowCommandCatalog.rows, id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(row, id: \.self) { key in
                            keycap(key)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            selectionCaption

            HStack(spacing: 14) {
                ForEach(WindowCommandFamily.allCases) { family in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(family.tint)
                            .frame(width: 10, height: 10)
                        Text(family.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Modèle

    fileprivate struct KeyEntry: Identifiable {
        let id: String
        let spec: WindowCommandSpec
        let badge: String
    }

    private func entries(for key: String) -> [KeyEntry] {
        WindowCommandCatalog.all.compactMap { spec in
            guard let shortcut = settings.shortcut(for: spec.action),
                  shortcut.key.lowercased() == key
            else { return nil }
            return KeyEntry(
                id: spec.id,
                spec: spec,
                badge: "\(shortcut.modifier.symbolPrefix)\(shortcut.keyDisplayName)"
            )
        }
    }

    private func keycap(_ key: String) -> some View {
        let keyEntries = entries(for: key)
        return MapKeycap(
            key: key,
            entries: keyEntries,
            isSelected: selectedKey == key,
            onSelect: { selectedKey = selectedKey == key ? nil : key }
        )
        .frame(width: key == "space" ? 110 : 46)
    }

    @ViewBuilder
    private var selectionCaption: some View {
        let keyEntries = selectedKey.map { entries(for: $0) } ?? []
        if keyEntries.isEmpty {
            Text(localizedString("Select a key to see its command."))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(keyEntries) { entry in
                    HStack(spacing: 8) {
                        WindowCommandIcon(spec: entry.spec, tint: entry.spec.family.tint)
                        Text(localizedString(entry.spec.title))
                            .font(.subheadline)
                        Spacer()
                        Text(entry.badge)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct MapKeycap: View {
    let key: String
    let entries: [KeyboardShortcutMapView.KeyEntry]
    let isSelected: Bool
    let onSelect: () -> Void

    private var legend: String {
        KeyboardShortcutSetting(key: key, modifier: .controlOption).keyDisplayName
    }

    private var tint: Color {
        entries.first?.spec.family.tint ?? .accentColor
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                if entries.isEmpty {
                    Spacer()
                    Text(legend)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Spacer()
                } else {
                    HStack(spacing: 5) {
                        ForEach(entries) { entry in
                            WindowCommandIcon(spec: entry.spec, tint: entry.spec.family.tint)
                                .frame(width: 17, height: 13)
                        }
                    }
                    .frame(height: 13)
                    HStack(spacing: 3) {
                        ForEach(entries) { entry in
                            Text(entry.badge)
                                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(entry.spec.family.tint)
                        }
                    }
                    .frame(height: 10)
                    Text(legend)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(entries.isEmpty ? Color.clear : tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : (entries.isEmpty ? Color(nsColor: .separatorColor).opacity(0.6) : tint.opacity(0.45)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(height: 50)
        .help(helpText)
        .accessibilityLabel(entries.isEmpty ? legend : helpText.replacingOccurrences(of: "\n", with: ", "))
    }

    private var helpText: String {
        entries.map { "\(localizedString($0.spec.title)) — \($0.badge)" }.joined(separator: "\n")
    }
}
