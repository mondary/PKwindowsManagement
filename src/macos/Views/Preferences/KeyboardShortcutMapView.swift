import SwiftUI

/// Carte clavier des raccourcis de fenêtres : chaque touche montre l'icône de sa
/// position et son rappel de raccourci. La carte suit les liaisons courantes.
struct KeyboardShortcutMapView: View {
    @ObservedObject var settings: AppSettings
    let availableWidth: CGFloat
    @State private var selectedKey: String?

    private let keySpacing: CGFloat = 6
    private var keyWidth: CGFloat {
        let columns = CGFloat(WindowCommandCatalog.rows.map(\.count).max() ?? 12)
        return max(40, (availableWidth - 28 - (columns - 1) * keySpacing) / columns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("Keyboard map"))
                .font(.headline)
            Text(localizedString("Every key shows its window placement and shortcut. The map follows your current shortcuts."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: keySpacing) {
                ForEach(WindowCommandCatalog.rows, id: \.self) { row in
                    HStack(spacing: keySpacing) {
                        ForEach(row, id: \.self) { key in
                            keycap(key, height: rowHeight(row))
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            selectionCaption

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 10) {
                ForEach(WindowCommandFamily.allCases) { family in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(family.tint)
                            .frame(width: 11, height: 11)
                        Text(family.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
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

    private func rowHeight(_ row: [String]) -> CGFloat {
        let commandCount = row.map { entries(for: $0).count }.max() ?? 0
        return max(88, 36 + CGFloat(commandCount) * (keyWidth >= 72 ? 26 : 40))
    }

    private func keycap(_ key: String, height: CGFloat) -> some View {
        let keyEntries = entries(for: key)
        return MapKeycap(
            key: key,
            width: key == "space" ? keyWidth * 2 + keySpacing : keyWidth,
            entries: keyEntries,
            isSelected: selectedKey == key,
            onSelect: { selectedKey = selectedKey == key ? nil : key }
        )
        .frame(width: key == "space" ? keyWidth * 2 + keySpacing : keyWidth, height: height)
    }

    @ViewBuilder
    private var selectionCaption: some View {
        let keyEntries = selectedKey.map { entries(for: $0) } ?? []
        if keyEntries.isEmpty {
            Text(localizedString("Select a key to see its command."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(keyEntries) { entry in
                    HStack(spacing: 8) {
                        WindowCommandIcon(spec: entry.spec, tint: entry.spec.family.tint)
                        Text(localizedString(entry.spec.title))
                            .font(.body)
                        Spacer()
                        Text(entry.badge)
                            .font(.system(.body, design: .monospaced))
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
    let width: CGFloat
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
            VStack(spacing: 6) {
                Text(legend)
                    .font(.system(size: width >= 72 ? 18 : 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(entries.isEmpty ? .secondary : .primary)
                if entries.isEmpty {
                    EmptyView()
                } else {
                    ForEach(entries) { entry in
                        let layout = width >= 72
                            ? AnyLayout(HStackLayout(spacing: 5))
                            : AnyLayout(VStackLayout(spacing: 3))
                        layout {
                            WindowCommandIcon(spec: entry.spec, tint: entry.spec.family.tint)
                                .scaleEffect(1.3)
                                .frame(width: 23, height: 18)
                            Text(entry.badge)
                                .font(.system(size: width >= 100 ? 13 : 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(entry.spec.family.tint)
                                .lineLimit(1)
                        }
                    }
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
        .help(helpText)
        .accessibilityLabel(entries.isEmpty ? legend : helpText.replacingOccurrences(of: "\n", with: ", "))
    }

    private var helpText: String {
        entries.map { "\(localizedString($0.spec.title)) — \($0.badge)" }.joined(separator: "\n")
    }
}
