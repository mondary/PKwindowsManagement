import AppKit
import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                gridLayoutSection
                perDisplayLayoutsSection
                sizingSection
                sortingSection
                navigationSection
            }
            .padding(24)
        }
    }

    private var gridLayoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grid Layout")
                .font(.headline)

            HStack(spacing: 28) {
                Stepper(value: $settings.launchpadGridColumns, in: 4...20) {
                    HStack(spacing: 6) {
                        Text("Columns")
                        Text("\(settings.launchpadGridColumns)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $settings.launchpadGridRows, in: 3...20) {
                    HStack(spacing: 6) {
                        Text("Rows")
                        Text("\(settings.launchpadGridRows)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(localizedFormat("%d apps visible", settings.launchpadGridColumns * settings.launchpadGridRows))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    private var sizingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sizing")
                .font(.headline)

            HStack(spacing: 28) {
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
        }
    }

    private var sortingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Ordering")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Sort apps by", selection: $settings.launchpadAppSortMode) {
                    ForEach(LaunchpadAppSortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 360)

                Text(localizedString(settings.launchpadAppSortMode == .color
                     ? "Heuristic sort based on the dominant icon color."
                     : settings.launchpadAppSortMode == .recent
                     ? "Most recently used apps are shown first."
                     : "Apps are sorted alphabetically."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
    }

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Navigation")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Scroll mode", selection: $settings.launchpadGridNavigation) {
                    ForEach(LaunchpadGridNavigation.allCases) { navigation in
                        Text(navigation.title).tag(navigation)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)

                Text(localizedString(settings.launchpadGridNavigation == .horizontalPages
                     ? "Swipe horizontally to move page by page."
                     : "Scroll vertically through all applications."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
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
