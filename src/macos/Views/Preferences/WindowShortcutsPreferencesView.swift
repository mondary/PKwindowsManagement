import SwiftUI

struct WindowShortcutsPreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var canvas = HorizontalCanvasService.shared

    private var halvesEntries: [WindowCommandSpec] { WindowCommandCatalog.halves }

    private var moveEntries: [WindowCommandSpec] { WindowCommandCatalog.move }

    private var quartersEntries: [WindowCommandSpec] { WindowCommandCatalog.quarters }

    private var fourthsEntries: [WindowCommandSpec] { WindowCommandCatalog.fourths }

    private var thirdsEntries: [WindowCommandSpec] { WindowCommandCatalog.thirds }

    private var twoThirdsEntries: [WindowCommandSpec] { WindowCommandCatalog.twoThirds }

    private var threeFourthsEntries: [WindowCommandSpec] { WindowCommandCatalog.threeFourths }

    private var horizontalEntries: [WindowCommandSpec] { WindowCommandCatalog.horizontal }

    private var sixthsEntries: [WindowCommandSpec] { WindowCommandCatalog.sixths }

    private var displaysEntries: [WindowCommandSpec] { WindowCommandCatalog.displays }

    private var desktopsEntries: [WindowCommandSpec] { WindowCommandCatalog.desktops }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(localizedString("Window management"))
                        .font(.title3.weight(.semibold))

                    KeyboardShortcutMapView(settings: settings)

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
        canvasSection()

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Halves", entries: halvesEntries)
            sectionCard(title: "Move", entries: moveEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Quarters", entries: quartersEntries)
            sectionCard(title: "Fourth Columns", entries: fourthsEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Third Columns", entries: thirdsEntries)
            sectionCard(title: "Two Thirds", entries: twoThirdsEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Three Fourths", entries: threeFourthsEntries)
            sectionCard(title: "Horizontal", entries: horizontalEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Sixths", entries: sixthsEntries)
            sectionCard(title: "Displays", entries: displaysEntries)
        }

        HStack(alignment: .top, spacing: 16) {
            sectionCard(title: "Desktops", entries: desktopsEntries)
            desktopOptionsCard()
        }

        sizeSection()
    }

    @ViewBuilder
    private var narrowLayout: some View {
        generalMarginSection()
        canvasSection()
        sectionCard(title: "Move", entries: moveEntries)
        sectionCard(title: "Halves", entries: halvesEntries)
        sectionCard(title: "Quarters", entries: quartersEntries)
        sectionCard(title: "Fourth Columns", entries: fourthsEntries)
        sectionCard(title: "Third Columns", entries: thirdsEntries)
        sectionCard(title: "Two Thirds", entries: twoThirdsEntries)
        sectionCard(title: "Three Fourths", entries: threeFourthsEntries)
        sectionCard(title: "Horizontal", entries: horizontalEntries)
        sectionCard(title: "Sixths", entries: sixthsEntries)
        sectionCard(title: "Displays", entries: displaysEntries)
        sectionCard(title: "Desktops", entries: desktopsEntries)
        desktopOptionsCard()
        sizeSection()
    }

    private func canvasSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionCard(title: "Horizontal Canvas", entries: WindowCommandCatalog.canvas)
            HStack {
                Button(localizedString("Toggle Horizontal Canvas")) { canvas.perform(.toggle) }
                Button(localizedString("Restore Canvas")) { canvas.perform(.restore) }
                Text(localizedString(canvas.activeDisplayIDs.isEmpty ? "Canvas inactive" : "Canvas active"))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(localizedString("Rows per column"))
                Picker(localizedString("Rows per column"), selection: $settings.canvasRowsPerColumn) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 110)
                Text(localizedString("Applies the next time the Canvas starts."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(localizedString("Open Canvas arranges windows in scrolling columns with one or two rows. Three columns fit on wide screens, two on smaller screens. Hold Option and scroll with the trackpad or mouse, or use the previous/next column shortcuts. Exiting restores the original window positions and sizes; a placement command exits Canvas before moving the selected window."))
                .font(.caption).foregroundStyle(.secondary)
            if !canvas.message.isEmpty {
                Text(canvas.message).font(.caption).foregroundStyle(.orange)
            }
        }
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

    private func sizeSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("Size & Position"))
                .font(.headline)
            VStack(spacing: 0) {
                windowRow(WindowCommandCatalog.size.fullScreen)
                Divider()
                windowRow(WindowCommandCatalog.size.toggleFullScreen)
                Divider()
                windowRow(WindowCommandCatalog.size.almostMaximize)
                Divider()
                windowRow(WindowCommandCatalog.size.maximizeAll)
                Divider()
                windowRow(WindowCommandCatalog.size.maximizeAllInApp)
                windowRow(WindowCommandCatalog.size.tileAll)
                Divider()
                marginEditor($settings.almostFullMargins)
                Divider()
                windowRow(WindowCommandCatalog.size.maximizeHeight)
                Divider()
                windowRow(WindowCommandCatalog.size.maximizeWidth)
                Divider()
                windowRow(WindowCommandCatalog.size.reasonableSize)
                Divider()
                windowRow(WindowCommandCatalog.size.restore)
                Divider()
                windowRow(WindowCommandCatalog.size.makeLarger)
                Divider()
                windowRow(WindowCommandCatalog.size.makeSmaller)
                Divider()
                windowRow(WindowCommandCatalog.size.center)
                Divider()
                marginEditor($settings.centerMargins)
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func desktopOptionsCard() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("New Desktop Options"))
                .font(.headline)
            VStack(spacing: 0) {
                Toggle(isOn: $settings.spaceWallpaperOnCreate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedString("Random wallpaper for new desktops"))
                        Text(localizedString("Picks a different image each time a desktop is created."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

                Divider()

                wallpaperFolderRow

                Divider()

                Toggle(isOn: $settings.spaceFollowMovedWindow) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedString("Follow window when moving"))
                        Text(localizedString("Switch to the destination desktop after moving a window."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

                Divider()

                Text(localizedString("Creating or closing a desktop—and following a moved window when enabled—briefly shows Mission Control. Private macOS APIs may change after system updates."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                Text(localizedString("Desktop reordering keeps its windows together. Disable automatic Spaces rearrangement in macOS to keep your chosen order."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var wallpaperFolderRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString("Wallpaper folder"))
                    .font(.body)
                Text(settings.spaceWallpaperFolder?.path ?? localizedString("No folder selected"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(localizedString("Choose…")) {
                chooseWallpaperFolder()
            }
            .controlSize(.small)
            if settings.spaceWallpaperFolder != nil {
                Button {
                    settings.spaceWallpaperFolder = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(localizedString("Clear"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func chooseWallpaperFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = localizedString("Pick the folder that stores your wallpapers.")
        if panel.runModal() == .OK, let url = panel.url {
            settings.spaceWallpaperFolder = url
        }
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
            WindowCommandIcon(spec: item)
        }
        .frame(width: 20, height: 20)
    }

    private func marginEditor(_ margins: Binding<WindowMargins>) -> some View {
        HStack(spacing: 16) {
            marginField("Top", margins.top)
            marginField("Bottom", margins.bottom)
            marginField("Left", margins.left)
            marginField("Right", margins.right)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func marginField(_ label: String, _ value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(localizedString(label))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                TextField(localizedString(label), value: Binding(
                    get: { value.wrappedValue },
                    set: { newValue in
                        guard let raw = newValue else { return }
                        value.wrappedValue = min(max(raw, 0), 25)
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(localizedString(label))
                .accessibilityValue("\(value.wrappedValue.formatted()) %")
                .frame(width: 46)
                .onMoveCommand { direction in
                    let step: CGFloat = direction == .up ? 1 : -1
                    value.wrappedValue = min(max(value.wrappedValue + step, 0), 25)
                }
                Text("%")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
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
