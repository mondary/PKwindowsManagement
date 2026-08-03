import SwiftUI

struct WindowShortcutsPreferencesView: View {
    @ObservedObject var settings: AppSettings

    private var halvesEntries: [WindowCommandSpec] {
        [
            .bound("Left Half", "rectangle.lefthalf.inset.filled", .windowLeftHalf),
            .bound("Right Half", "rectangle.righthalf.inset.filled", .windowRightHalf),
            .bound("Top Half", "rectangle.tophalf.inset.filled", .windowTopHalf),
            .bound("Bottom Half", "rectangle.bottomhalf.inset.filled", .windowBottomHalf),
        ]
    }

    private var quartersEntries: [WindowCommandSpec] {
        [
            .bound("Top Left", nil, .windowTopLeft, fraction: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            .bound("Top Right", nil, .windowTopRight, fraction: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)),
            .bound("Bottom Left", nil, .windowBottomLeft, fraction: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)),
            .bound("Bottom Right", nil, .windowBottomRight, fraction: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)),
        ]
    }

    private var thirdsEntries: [WindowCommandSpec] {
        [
            .bound("First Third", nil, .windowFirstThird, fraction: CGRect(x: 0, y: 0, width: 1 / 3, height: 1)),
            .bound("Center Third", nil, .windowCenterThird, fraction: CGRect(x: 1 / 3, y: 0, width: 1 / 3, height: 1)),
            .bound("Last Third", nil, .windowLastThird, fraction: CGRect(x: 2 / 3, y: 0, width: 1 / 3, height: 1)),
        ]
    }

    private var sixthsEntries: [WindowCommandSpec] {
        [
            .bound("Top Left Sixth", nil, .windowTopFirstSixth, fraction: CGRect(x: 0, y: 0, width: 1 / 3, height: 0.5)),
            .bound("Top Center Sixth", nil, .windowTopCenterSixth, fraction: CGRect(x: 1 / 3, y: 0, width: 1 / 3, height: 0.5)),
            .bound("Top Right Sixth", nil, .windowTopLastSixth, fraction: CGRect(x: 2 / 3, y: 0, width: 1 / 3, height: 0.5)),
            .bound("Bottom Left Sixth", nil, .windowBottomFirstSixth, fraction: CGRect(x: 0, y: 0.5, width: 1 / 3, height: 0.5)),
            .bound("Bottom Center Sixth", nil, .windowBottomCenterSixth, fraction: CGRect(x: 1 / 3, y: 0.5, width: 1 / 3, height: 0.5)),
            .bound("Bottom Right Sixth", nil, .windowBottomLastSixth, fraction: CGRect(x: 2 / 3, y: 0.5, width: 1 / 3, height: 0.5)),
        ]
    }

    private var displaysEntries: [WindowCommandSpec] {
        [
            .bound("Next Display", "arrow.right.to.line.compact", .windowNextDisplay),
            .bound("Previous Display", "arrow.left.to.line.compact", .windowPreviousDisplay),
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Window Management")
                        .font(.title3.weight(.semibold))

                    if geometry.size.width >= 760 {
                        wideLayout
                    } else {
                        narrowLayout
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private var wideLayout: some View {
        generalMarginSection()

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Halves", entries: halvesEntries)
            sectionCard(title: "Quarters", entries: quartersEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            maximizeSection()
            sectionCard(title: "Sixths", entries: sixthsEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Thirds", entries: thirdsEntries)
            sectionCard(title: "Displays", entries: displaysEntries)
        }
    }

    @ViewBuilder
    private var narrowLayout: some View {
        generalMarginSection()
        maximizeSection()
        sectionCard(title: "Halves", entries: halvesEntries)
        sectionCard(title: "Quarters", entries: quartersEntries)
        sectionCard(title: "Thirds", entries: thirdsEntries)
        sectionCard(title: "Sixths", entries: sixthsEntries)
        sectionCard(title: "Displays", entries: displaysEntries)
    }

    private func sectionCard(title: String, entries: [WindowCommandSpec]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString(title))
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(entries) { item in
                    windowRow(item)
                    if item.id != entries.last?.id { Divider() }
                }
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func maximizeSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("Maximize"))
                .font(.headline)
            VStack(spacing: 0) {
                windowRow(.bound("Fullscreen", "arrow.up.left.and.arrow.down.right", .windowFullScreen))
                Divider()
                windowRow(.bound("Almost Maximize", "arrow.up.left.and.arrow.down.right", .windowMaximize))
                Divider()
                marginEditor($settings.almostFullMargins)
                Divider()
                windowRow(.bound("Center", "circle.grid.cross", .windowCenter))
                Divider()
                marginEditor($settings.centerMargins)
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generalMarginSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("General Margins"))
                .font(.headline)
            VStack(spacing: 0) {
                Text(localizedString("Applied to every window position."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                marginEditor($settings.generalMargins)
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func windowRow(_ item: WindowCommandSpec) -> some View {
        HStack(spacing: 10) {
            iconPill(item)
            Text(localizedString(item.title))
                .font(.body)
            Spacer()

            CompactShortcutField(shortcut: shortcutBinding(for: item.action))

            Button {
                settings.clearShortcut(for: item.action)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(localizedString("Clear"))

            Button {
                settings.resetShortcut(for: item.action)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(localizedString("Reset"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func iconPill(_ item: WindowCommandSpec) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
            if let fraction = item.fraction {
                splitIcon(fraction)
            } else {
                Image(systemName: item.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: 20, height: 20)
    }

    private func splitIcon(_ fraction: CGRect) -> some View {
        let size: CGFloat = 12
        return ZStack {
            RoundedRectangle(cornerRadius: 1.5)
                .stroke(Color.accentColor, lineWidth: 1)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor)
                .frame(width: max(1, size * fraction.width), height: max(1, size * fraction.height))
                .offset(x: (fraction.midX - 0.5) * size, y: (fraction.midY - 0.5) * size)
        }
        .frame(width: size, height: size)
    }

    private func marginEditor(_ margins: Binding<WindowMargins>) -> some View {
        HStack(spacing: 16) {
            marginField("T", margins.top)
            marginField("B", margins.bottom)
            marginField("L", margins.left)
            marginField("R", margins.right)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func marginField(_ label: String, _ value: Binding<CGFloat>) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 10)
            TextField("", value: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    guard let raw = newValue else { return }
                    value.wrappedValue = min(max(raw, 0), 25)
                }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 46)
            Text("%")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func shortcutBinding(for action: ShortcutAction) -> Binding<KeyboardShortcutSetting?> {
        Binding(
            get: { settings.shortcut(for: action) },
            set: { shortcut in
                if let shortcut {
                    settings.setShortcut(shortcut, for: action)
                } else {
                    settings.clearShortcut(for: action)
                }
            }
        )
    }
}

private struct WindowCommandSpec: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let fraction: CGRect?
    let action: ShortcutAction

    static func bound(_ title: String, _ symbol: String?, _ action: ShortcutAction, fraction: CGRect? = nil) -> Self {
        .init(id: title, title: title, symbol: symbol ?? "", fraction: fraction, action: action)
    }
}
