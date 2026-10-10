import SwiftUI

struct WindowShortcutsPreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var canvas = HorizontalCanvasService.shared

    private var halvesEntries: [WindowCommandSpec] {
        [
            .bound("Left Half", "rectangle.lefthalf.inset.filled", .windowLeftHalf),
            .bound("Right Half", "rectangle.righthalf.inset.filled", .windowRightHalf),
            .bound("Top Half", "rectangle.tophalf.inset.filled", .windowTopHalf),
            .bound("Bottom Half", "rectangle.bottomhalf.inset.filled", .windowBottomHalf),
        ]
    }

    private var moveEntries: [WindowCommandSpec] {
        [
            .bound("Move Left", "arrow.left.to.line.compact", .windowMoveLeft),
            .bound("Move Right", "arrow.right.to.line.compact", .windowMoveRight),
            .bound("Move Up", "arrow.up.to.line.compact", .windowMoveUp),
            .bound("Move Down", "arrow.down.to.line.compact", .windowMoveDown),
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

    private var fourthsEntries: [WindowCommandSpec] {
        [
            .bound("First Fourth", nil, .windowFirstFourth, fraction: CGRect(x: 0, y: 0, width: 0.25, height: 1)),
            .bound("Second Fourth", nil, .windowSecondFourth, fraction: CGRect(x: 0.25, y: 0, width: 0.25, height: 1)),
            .bound("Third Fourth", nil, .windowThirdFourth, fraction: CGRect(x: 0.5, y: 0, width: 0.25, height: 1)),
            .bound("Last Fourth", nil, .windowLastFourth, fraction: CGRect(x: 0.75, y: 0, width: 0.25, height: 1)),
        ]
    }

    private var thirdsEntries: [WindowCommandSpec] {
        [
            .bound("First Third", nil, .windowFirstThird, fraction: CGRect(x: 0, y: 0, width: 0.3334, height: 1)),
            .bound("Center Third", nil, .windowCenterThird, fraction: CGRect(x: 0.3333, y: 0, width: 0.3334, height: 1)),
            .bound("Last Third", nil, .windowLastThird, fraction: CGRect(x: 0.6667, y: 0, width: 0.3333, height: 1)),
        ]
    }

    private var twoThirdsEntries: [WindowCommandSpec] {
        [
            .bound("First Two Thirds", nil, .windowFirstTwoThirds, fraction: CGRect(x: 0, y: 0, width: 0.6667, height: 1)),
            .bound("Center Two Thirds", nil, .windowCenterTwoThirds, fraction: CGRect(x: 0.1667, y: 0, width: 0.6666, height: 1)),
            .bound("Last Two Thirds", nil, .windowLastTwoThirds, fraction: CGRect(x: 0.3333, y: 0, width: 0.6667, height: 1)),
        ]
    }

    private var threeFourthsEntries: [WindowCommandSpec] {
        [
            .bound("First Three Fourths", nil, .windowFirstThreeFourths, fraction: CGRect(x: 0, y: 0, width: 0.75, height: 1)),
            .bound("Center Three Fourths", nil, .windowCenterThreeFourths, fraction: CGRect(x: 0.125, y: 0, width: 0.75, height: 1)),
            .bound("Last Three Fourths", nil, .windowLastThreeFourths, fraction: CGRect(x: 0.25, y: 0, width: 0.75, height: 1)),
        ]
    }

    private var horizontalEntries: [WindowCommandSpec] {
        [
            .bound("Top Third", nil, .windowTopThird, fraction: CGRect(x: 0, y: 0, width: 1, height: 0.3334)),
            .bound("Bottom Third", nil, .windowBottomThird, fraction: CGRect(x: 0, y: 0.6667, width: 1, height: 0.3333)),
            .bound("Top Two Thirds", nil, .windowTopTwoThirds, fraction: CGRect(x: 0, y: 0, width: 1, height: 0.6667)),
            .bound("Bottom Two Thirds", nil, .windowBottomTwoThirds, fraction: CGRect(x: 0, y: 0.3333, width: 1, height: 0.6667)),
        ]
    }

    private var sixthsEntries: [WindowCommandSpec] {
        [
            .bound("Top Left Sixth", nil, .windowTopFirstSixth, fraction: CGRect(x: 0, y: 0, width: 0.3334, height: 0.5)),
            .bound("Top Center Sixth", nil, .windowTopCenterSixth, fraction: CGRect(x: 0.3333, y: 0, width: 0.3334, height: 0.5)),
            .bound("Top Right Sixth", nil, .windowTopLastSixth, fraction: CGRect(x: 0.6667, y: 0, width: 0.3333, height: 0.5)),
            .bound("Bottom Left Sixth", nil, .windowBottomFirstSixth, fraction: CGRect(x: 0, y: 0.5, width: 0.3334, height: 0.5)),
            .bound("Bottom Center Sixth", nil, .windowBottomCenterSixth, fraction: CGRect(x: 0.3333, y: 0.5, width: 0.3334, height: 0.5)),
            .bound("Bottom Right Sixth", nil, .windowBottomLastSixth, fraction: CGRect(x: 0.6667, y: 0.5, width: 0.3333, height: 0.5)),
        ]
    }

    private var displaysEntries: [WindowCommandSpec] {
        [
            .bound("Next Display", "arrow.forward.square", .windowNextDisplay),
            .bound("Previous Display", "arrow.backward.square", .windowPreviousDisplay),
        ]
    }

    private var desktopsEntries: [WindowCommandSpec] {
        [
            .bound("New Desktop", "plus.rectangle.on.rectangle", .desktopCreate),
            .bound("Close Current Desktop", "minus.rectangle", .desktopCloseCurrent),
            .bound("Move Window to Next Desktop", "arrow.right.square", .windowNextDesktop),
            .bound("Move Window to Previous Desktop", "arrow.left.square", .windowPreviousDesktop),
            .bound("Move Desktop Left", "rectangle.stack.badge.minus", .desktopMoveLeft),
            .bound("Move Desktop Right", "rectangle.stack.badge.plus", .desktopMoveRight),
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(localizedString("Window management"))
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
            sectionCard(title: "Horizontal Canvas", entries: [
                .bound("Toggle Horizontal Canvas", "rectangle.split.3x1", .canvasToggle),
                .bound("Previous Canvas Window", "arrow.left", .canvasPrevious),
                .bound("Next Canvas Window", "arrow.right", .canvasNext),
                .bound("Restore Canvas", "arrow.uturn.backward", .canvasRestore),
            ])
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
                windowRow(.bound("Fullscreen", "arrow.up.left.and.arrow.down.right", .windowFullScreen))
                Divider()
                windowRow(.bound("Toggle Fullscreen", "rectangle.inset.fill", .windowToggleFullScreen))
                Divider()
                windowRow(.bound("Almost Maximize", nil, .windowMaximize, fraction: CGRect(x: 0.045, y: 0.045, width: 0.91, height: 0.91)))
                Divider()
                windowRow(.bound("Maximize All Windows", "rectangle.on.rectangle", .windowMaximizeAll))
                Divider()
                windowRow(.bound("Maximize All Windows (Current App)", "rectangle.stack", .windowMaximizeAllInApp))
                windowRow(.bound("Tile All Windows", nil, .windowTileAll, fraction: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)))
                Divider()
                marginEditor($settings.almostFullMargins)
                Divider()
                windowRow(.bound("Maximize Height", "arrow.up.and.down", .windowMaximizeHeight))
                Divider()
                windowRow(.bound("Maximize Width", "arrow.left.and.right", .windowMaximizeWidth))
                Divider()
                windowRow(.bound("Reasonable Size", nil, .windowReasonableSize, fraction: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)))
                Divider()
                windowRow(.bound("Restore", "arrow.uturn.backward", .windowRestore))
                Divider()
                windowRow(.bound("Make Larger", "arrow.up.left.and.arrow.down.right", .windowMakeLarger))
                Divider()
                windowRow(.bound("Make Smaller", "arrow.down.right.and.arrow.up.left", .windowMakeSmaller))
                Divider()
                windowRow(.bound("Center", "circle.grid.cross", .windowCenter))
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
            if let fraction = item.fraction {
                splitIcon(fraction)
            } else if item.action == .windowMaximizeAll {
                allScreensIcon
            } else if item.action == .windowMaximizeAllInApp {
                appStackIcon
            } else {
                Image(systemName: item.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: 20, height: 20)
    }

    // Deux écrans côte à côte, chacun avec sa fenêtre presque pleine
    private var allScreensIcon: some View {
        HStack(spacing: 1.5) {
            miniScreen
            miniScreen
        }
        .frame(width: 15, height: 12)
    }

    private var miniScreen: some View {
        RoundedRectangle(cornerRadius: 1.2)
            .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 0.8)
                    .fill(Color.accentColor)
                    .padding(1.5)
            )
    }

    // Un écran avec deux fenêtres empilées de l'app active
    private var appStackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.accentColor.opacity(0.4))
                .frame(width: 9, height: 7)
                .offset(x: -1.5, y: -1.5)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.accentColor)
                .frame(width: 9, height: 7)
                .offset(x: 1.5, y: 1.5)
        }
        .frame(width: 15, height: 12)
    }

    // L'entier n (2…6) qui aligne le mieux `value` sur k/n :
    // 0.667 → 3 (deux tiers), 0.75 → 4 (trois quarts), 0.5 → 2…
    private func bestDenominator(_ value: CGFloat) -> Int {
        var best = 2
        var bestError = CGFloat.greatestFiniteMagnitude
        for n in 2...6 {
            let k = (value * CGFloat(n)).rounded()
            let error = abs(value - k / CGFloat(n))
            if error < bestError - 0.0001 {
                bestError = error
                best = n
            }
        }
        return best
    }

    @ViewBuilder
    private func splitIcon(_ fraction: CGRect) -> some View {
        let canvasW: CGFloat = 15
        let canvasH: CGFloat = 12
        let gap: CGFloat = 1
        // Garde-fou : une fraction nulle rendrait la division infinie (crash)
        let width = max(0.05, min(1, fraction.width))
        let height = max(0.05, min(1, fraction.height))

        // Fenêtre flottante centrée (ex. Taille raisonnable) : contour + rectangle intérieur
        if fraction.minX > 0.01, fraction.minY > 0.01,
           fraction.maxX < 0.99, fraction.maxY < 0.99 {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(Color.accentColor)
                    .frame(width: max(2, canvasW * width), height: max(2, canvasH * height))
            }
            .frame(width: canvasW, height: canvasH)
        } else {
            // Dénominateur du découpage : l'entier n (2…6) qui aligne le mieux
            // la largeur sur k/n — deux tiers → 3 colonnes, trois quarts → 4…
            let cols = width >= 0.99 ? 1 : bestDenominator(width)
            let rows = height >= 0.99 ? 1 : bestDenominator(height)
            let activeCols = Int((width * CGFloat(cols)).rounded())
            let activeRows = Int((height * CGFloat(rows)).rounded())
            let colStart = max(0, min(Int((fraction.minX * CGFloat(cols)).rounded()), cols - activeCols))
            let rowStart = max(0, min(Int((fraction.minY * CGFloat(rows)).rounded()), rows - activeRows))
            let colEnd = colStart + activeCols
            let rowEnd = rowStart + activeRows

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { col in
                            let active = col >= colStart && col < colEnd && row >= rowStart && row < rowEnd
                            RoundedRectangle(cornerRadius: 1.2)
                                .fill(active ? Color.accentColor : Color.accentColor.opacity(0.18))
                        }
                    }
                }
            }
            .frame(width: canvasW, height: canvasH)
        }
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
