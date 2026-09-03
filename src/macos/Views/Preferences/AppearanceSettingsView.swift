import AppKit
import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                gridAndSizingSection
                perDisplayLayoutsSection
                sortingSection
                navigationSection
            }
            .padding(24)
        }
    }

    private var gridAndSizingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grid & Sizing")
                .font(.headline)

            HStack(alignment: .top, spacing: 20) {
                GridPreviewView(
                    columns: settings.launchpadGridColumns,
                    rows: settings.launchpadGridRows,
                    iconSize: settings.launchpadIconSize,
                    columnGap: settings.launchpadColumnSpacing,
                    rowGap: settings.launchpadRowSpacing
                )
                .frame(width: 230, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Stepper(value: $settings.launchpadGridColumns, in: 4...20) {
                        stepperLabel("Columns", value: settings.launchpadGridColumns)
                    }
                    Stepper(value: $settings.launchpadGridRows, in: 3...20) {
                        stepperLabel("Rows", value: settings.launchpadGridRows)
                    }
                    Divider()
                    Stepper(value: $settings.launchpadIconSize, in: 28...96, step: 4) {
                        stepperLabel("Icon size", value: settings.launchpadIconSize)
                    }
                    Stepper(value: $settings.launchpadColumnSpacing, in: 4...48, step: 2) {
                        stepperLabel("Column gap", value: settings.launchpadColumnSpacing)
                    }
                    Stepper(value: $settings.launchpadRowSpacing, in: 4...48, step: 2) {
                        stepperLabel("Row gap", value: settings.launchpadRowSpacing)
                    }
                }

                Spacer()

                Text(localizedFormat("%d apps visible", settings.launchpadGridColumns * settings.launchpadGridRows))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepperLabel(_ title: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Text("\(value)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var perDisplayLayoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Display Layouts")
                .font(.headline)

            Text("Assign a different grid to each connected monitor. Screens without a custom profile use the global grid above.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(displayEntries) { entry in
                    displayRow(for: entry)
                }
            }
        }
    }

    private var sortingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Ordering")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(LaunchpadAppSortMode.allCases) { mode in
                    PreviewCard(title: mode.title, isSelected: settings.launchpadAppSortMode == mode) {
                        settings.launchpadAppSortMode = mode
                    } thumbnail: {
                        sortThumbnail(mode)
                    }
                }

                Spacer()
            }

            Text(localizedString(settings.launchpadAppSortMode == .color
                 ? "Heuristic sort based on the dominant icon color."
                 : settings.launchpadAppSortMode == .recent
                 ? "Most recently used apps are shown first."
                 : "Apps are sorted alphabetically."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func sortThumbnail(_ mode: LaunchpadAppSortMode) -> some View {
        switch mode {
        case .name:
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(["A", "F", "Z"].enumerated()), id: \.offset) { index, letter in
                    HStack(spacing: 5) {
                        Text(letter)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 12, height: 12)
                            .background(Color.accentColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.white.opacity(0.5))
                            .frame(height: 4)
                    }
                }
            }
            .padding(.horizontal, 14)
        case .recent:
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                        .frame(height: 4)
                }
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white.opacity(0.45))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
            }
            .padding(.horizontal, 14)
        case .color:
            let palette: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple]
            VStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { column in
                            Circle()
                                .fill(palette[row * 4 + column])
                                .frame(width: 11, height: 11)
                        }
                    }
                }
            }
        }
    }

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Navigation")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(LaunchpadGridNavigation.allCases) { navigation in
                    PreviewCard(title: navigation.title, isSelected: settings.launchpadGridNavigation == navigation) {
                        settings.launchpadGridNavigation = navigation
                    } thumbnail: {
                        navigationThumbnail(navigation)
                    }
                }

                Spacer()
            }

            Text(localizedString(settings.launchpadGridNavigation == .horizontalPages
                 ? "Swipe horizontally to move page by page."
                 : "Scroll vertically through all applications."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func navigationThumbnail(_ navigation: LaunchpadGridNavigation) -> some View {
        switch navigation {
        case .vertical:
            HStack(spacing: 10) {
                VStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(Color.white.opacity(0.75))
                            .frame(width: 12, height: 12)
                    }
                }
                VStack(spacing: 14) {
                    Image(systemName: "chevron.up")
                    Image(systemName: "chevron.down")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            }
        case .horizontalPages:
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(spacing: 4) {
                        ForEach(0..<2, id: \.self) { _ in
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color.white.opacity(0.75))
                                    .frame(width: 9, height: 9)
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color.white.opacity(0.75))
                                    .frame(width: 9, height: 9)
                            }
                        }
                    }
                    .padding(5)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func displayRow(for entry: DisplayEntry) -> some View {
        let profile = settings.launchpadDisplayProfile(for: entry.id)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.screen.localizedName)
                        .font(.body.weight(.medium))
                    Text("\(Int(entry.screen.frame.width)) × \(Int(entry.screen.frame.height))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("Custom layout", isOn: customLayoutBinding(for: entry))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if let profile {
                HStack(spacing: 28) {
                    Stepper(value: displayColumnsBinding(for: entry), in: 4...20) {
                        HStack(spacing: 6) {
                            Text("Columns")
                            Text("\(profile.columns)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: displayRowsBinding(for: entry), in: 3...20) {
                        HStack(spacing: 6) {
                            Text("Rows")
                            Text("\(profile.rows)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(localizedFormat("%d apps visible", profile.columns * profile.rows))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            } else {
                Text(localizedFormat("Uses global %d × %d", settings.launchpadGridColumns, settings.launchpadGridRows))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var displayEntries: [DisplayEntry] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.launchpadDisplayID else { return nil }
            return DisplayEntry(id: id, screen: screen)
        }
    }

    private func customLayoutBinding(for entry: DisplayEntry) -> Binding<Bool> {
        Binding(
            get: { settings.launchpadDisplayProfile(for: entry.id) != nil },
            set: { enabled in
                if enabled {
                    if settings.launchpadDisplayProfile(for: entry.id) == nil {
                        settings.setLaunchpadDisplayProfile(
                            .init(
                                displayID: entry.id,
                                displayName: entry.screen.localizedName,
                                columns: settings.launchpadGridColumns,
                                rows: settings.launchpadGridRows
                            )
                        )
                    }
                } else {
                    settings.removeLaunchpadDisplayProfile(for: entry.id)
                }
            }
        )
    }

    private func displayColumnsBinding(for entry: DisplayEntry) -> Binding<Int> {
        Binding(
            get: { settings.launchpadDisplayProfile(for: entry.id)?.columns ?? settings.launchpadGridColumns },
            set: { value in
                guard var profile = settings.launchpadDisplayProfile(for: entry.id) else { return }
                profile.columns = value
                settings.setLaunchpadDisplayProfile(profile)
            }
        )
    }

    private func displayRowsBinding(for entry: DisplayEntry) -> Binding<Int> {
        Binding(
            get: { settings.launchpadDisplayProfile(for: entry.id)?.rows ?? settings.launchpadGridRows },
            set: { value in
                guard var profile = settings.launchpadDisplayProfile(for: entry.id) else { return }
                profile.rows = value
                settings.setLaunchpadDisplayProfile(profile)
            }
        )
    }
}

private struct DisplayEntry: Identifiable {
    let id: CGDirectDisplayID
    let screen: NSScreen
}

private struct PreviewCard<Thumbnail: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let thumbnail: () -> Thumbnail

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                thumbnail()
                    .frame(width: 108, height: 68)
                    .background(launchpadDesktopGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                    )

                HStack(spacing: 4) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GridPreviewView: View {
    let columns: Int
    let rows: Int
    let iconSize: Int
    let columnGap: Int
    let rowGap: Int

    private let palette: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple, .pink, .mint]

    var body: some View {
        GeometryReader { geo in
            let unitWidth = CGFloat(columns) * CGFloat(iconSize) + CGFloat(columns + 1) * CGFloat(columnGap)
            let unitHeight = CGFloat(rows) * CGFloat(iconSize) + CGFloat(rows + 1) * CGFloat(rowGap)
            let scale = min(geo.size.width / unitWidth, geo.size.height / unitHeight)
            let cell = CGFloat(iconSize) * scale
            let gapX = CGFloat(columnGap) * scale
            let gapY = CGFloat(rowGap) * scale

            VStack(spacing: gapY) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gapX) {
                        ForEach(0..<columns, id: \.self) { column in
                            RoundedRectangle(cornerRadius: cell * 0.22, style: .continuous)
                                .fill(palette[(row * columns + column) % palette.count].opacity(0.85))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
