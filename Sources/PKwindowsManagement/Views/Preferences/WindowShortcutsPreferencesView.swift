import SwiftUI

struct WindowShortcutsPreferencesView: View {
    @ObservedObject var settings: AppSettings
    private let snapService = WindowSnapService()

    private let quickActions: [WindowCommandSpec] = [
        .bound("Almost Maximize", "arrow.up.left.and.arrow.down.right", .windowMaximize),
        .bound("Center", "circle.grid.cross", .windowCenter),
        .bound("Left Half", "rectangle.lefthalf.inset.filled", .windowLeftHalf),
        .bound("Right Half", "rectangle.righthalf.inset.filled", .windowRightHalf),
        .bound("Top Half", "rectangle.tophalf.inset.filled", .windowTopHalf),
        .bound("Bottom Half", "rectangle.bottomhalf.inset.filled", .windowBottomHalf),
        .bound("Top Left", "uiwindow.split.2x1", .windowTopLeft),
        .bound("Top Right", "uiwindow.split.2x1", .windowTopRight),
        .bound("Bottom Left", "uiwindow.split.2x1", .windowBottomLeft),
        .bound("Bottom Right", "uiwindow.split.2x1", .windowBottomRight),
        .bound("First Third", "rectangle.split.3x1", .windowFirstThird),
        .bound("Center Third", "rectangle.split.3x1", .windowCenterThird),
        .bound("Last Third", "rectangle.split.3x1", .windowLastThird),
        .bound("Next Display", "arrow.right.to.line.compact", .windowNextDisplay),
        .bound("Previous Display", "arrow.left.to.line.compact", .windowPreviousDisplay)
    ]

    // Catalog inspired by your screenshots (Rectangle-like breadth).
    // Bound entries are active now; unbound entries are visible as roadmap "Record Hotkey" rows.
    private let fullCatalog: [WindowCommandSpec] = [
        .unbound("Maximize Height", "arrow.up.and.down"),
        .unbound("Maximize Width", "arrow.left.and.right"),
        .unbound("Make Smaller", "minus"),
        .unbound("Make Larger", "plus"),
        .unbound("Reasonable Size", "square.resize"),
        .unbound("Restore", "arrow.counterclockwise"),
        .unbound("First Fourth", "rectangle.split.4x1"),
        .unbound("Second Fourth", "rectangle.split.4x1"),
        .unbound("Third Fourth", "rectangle.split.4x1"),
        .unbound("Last Fourth", "rectangle.split.4x1"),
        .unbound("First Two Thirds", "rectangle.split.3x1"),
        .unbound("Center Two Thirds", "rectangle.split.3x1"),
        .unbound("Last Two Thirds", "rectangle.split.3x1"),
        .unbound("First Three Fourths", "rectangle.split.4x1"),
        .unbound("Center Three Fourths", "rectangle.split.4x1"),
        .unbound("Last Three Fourths", "rectangle.split.4x1"),
        .unbound("Top Third", "rectangle.topthird.inset.filled"),
        .unbound("Bottom Third", "rectangle.bottomthird.inset.filled"),
        .unbound("Top Two Thirds", "rectangle.split.3x1.fill"),
        .unbound("Bottom Two Thirds", "rectangle.split.3x1.fill"),
        .unbound("Top Left Quarter", "rectangle.inset.topleft.filled"),
        .unbound("Top Right Quarter", "rectangle.inset.topright.filled"),
        .unbound("Bottom Left Quarter", "rectangle.inset.bottomleft.filled"),
        .unbound("Bottom Right Quarter", "rectangle.inset.bottomright.filled"),
        .unbound("Top Left Sixth", "rectangle.3.group.bubble.left.fill"),
        .unbound("Top Center Sixth", "rectangle.3.group.bubble.middle.fill"),
        .unbound("Top Right Sixth", "rectangle.3.group.bubble.right.fill"),
        .unbound("Bottom Left Sixth", "rectangle.3.group.bubble.left.fill"),
        .unbound("Bottom Center Sixth", "rectangle.3.group.bubble.middle.fill"),
        .unbound("Bottom Right Sixth", "rectangle.3.group.bubble.right.fill"),
        .unbound("Move Left", "arrow.left"),
        .unbound("Move Right", "arrow.right"),
        .unbound("Move Up", "arrow.up"),
        .unbound("Move Down", "arrow.down"),
        .unbound("Toggle Fullscreen", "arrow.up.left.and.arrow.down.right")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Window Management")
                    .font(.title3.weight(.semibold))

                quickSplitPanel

                sectionCard(title: "Active Shortcuts", entries: quickActions, showEditor: true)
                sectionCard(title: "Extended Catalog", entries: fullCatalog, showEditor: false)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var quickSplitPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Splits (4 → 9)")
                .font(.headline)
            ForEach(4...9, id: \.self) { columns in
                HStack(spacing: 10) {
                    Text("\(columns)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .leading)
                    ForEach(0..<columns, id: \.self) { idx in
                        Button {
                            snapService.snapToColumns(total: columns, index: idx)
                        } label: {
                            ColumnGlyph(total: columns, index: idx)
                                .frame(width: 22, height: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func sectionCard(title: String, entries: [WindowCommandSpec], showEditor: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(entries) { item in
                    windowRow(item, editable: showEditor)
                    if item.id != entries.last?.id { Divider() }
                }
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @ViewBuilder
    private func windowRow(_ item: WindowCommandSpec, editable: Bool) -> some View {
        HStack(spacing: 10) {
            iconPill(symbol: item.symbol)
            Text(item.title)
                .font(.body)
            Spacer()

            if editable, let action = item.boundAction {
                Picker("", selection: modifierBinding(for: action)) {
                    ForEach(ShortcutModifierPreset.allCases) { modifier in
                        Text(modifier.displayName).tag(modifier)
                    }
                }
                .labelsHidden()
                .frame(width: 190)

                TextField(localizedString("key"), text: keyBinding(for: action))
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .frame(width: 72)

                Button(localizedString("reset")) {
                    settings.resetShortcut(for: action)
                }
                .frame(width: 64)
            } else {
                Text("Record Hotkey")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 180, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func iconPill(symbol: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 20, height: 20)
    }

    private func modifierBinding(for action: ShortcutAction) -> Binding<ShortcutModifierPreset> {
        Binding(
            get: { settings.shortcut(for: action).modifier },
            set: { modifier in
                var shortcut = settings.shortcut(for: action)
                shortcut.modifier = modifier
                settings.setShortcut(shortcut, for: action)
            }
        )
    }

    private func keyBinding(for action: ShortcutAction) -> Binding<String> {
        Binding(
            get: { settings.shortcut(for: action).key.uppercased() },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                var shortcut = settings.shortcut(for: action)
                shortcut.key = String(trimmed.suffix(1)).lowercased()
                settings.setShortcut(shortcut, for: action)
            }
        )
    }
}

private struct WindowCommandSpec: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let boundAction: ShortcutAction?

    static func bound(_ title: String, _ symbol: String, _ action: ShortcutAction) -> Self {
        .init(id: title, title: title, symbol: symbol, boundAction: action)
    }

    static func unbound(_ title: String, _ symbol: String) -> Self {
        .init(id: title, title: title, symbol: symbol, boundAction: nil)
    }
}

private struct ColumnGlyph: View {
    let total: Int
    let index: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let segment = w / CGFloat(max(total, 1))
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.secondary.opacity(0.55), lineWidth: 1)
                ForEach(1..<total, id: \.self) { i in
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 0.7)
                        .position(x: segment * CGFloat(i), y: h / 2)
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.75))
                    .frame(width: max(2, segment - 1), height: max(2, h - 4))
                    .position(x: segment * (CGFloat(index) + 0.5), y: h / 2)
            }
        }
    }
}
