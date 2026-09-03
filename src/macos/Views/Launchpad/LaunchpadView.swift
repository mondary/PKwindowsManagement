import AppKit
import SwiftUI

struct LaunchpadView: View {
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var shortcutTarget: LaunchableApp?
    @State private var commandFeedbackMessage: String?
    private let launcher = AppLauncherService()

    var body: some View {
        let apps = filteredApps
        VStack(alignment: .leading, spacing: 16) {
            activationSettings
                .padding(.horizontal, 24)
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text("Applications")
                    .font(.title2.weight(.semibold))
                TextField("Search apps or recent launches", text: $query)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 24)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14)], spacing: 14) {
                    ForEach(apps) { app in
                        VStack(spacing: 8) {
                            Button {
                                commandFeedbackMessage = launcher.launch(app, settings: settings)
                            } label: {
                                LaunchpadAppTile(app: app)
                            }
                            .buttonStyle(.plain)

                            Button(app.shortcut == nil ? localizedString("Assign shortcut") : shortcutLabel(for: app.shortcut)) {
                                shortcutTarget = app
                            }
                            .font(.system(size: 11, weight: .semibold))
                        }
                    }
                }
                .padding(24)
            }
        }
        .sheet(item: $shortcutTarget) { app in
            LaunchShortcutEditor(app: app, settings: settings)
                .frame(width: 420, height: 220)
        }
        .alert("Action Result", isPresented: commandFeedbackPresented) {
            Button("OK", role: .cancel) {
                commandFeedbackMessage = nil
            }
        } message: {
            Text(commandFeedbackMessage ?? "")
        }
        .task(id: settings.recentBundleIDs) { }
    }

    private var activationSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Launchpad Activation")
                .font(.headline)

            HStack(spacing: 12) {
                Text("Global shortcut")
                    .frame(width: 110, alignment: .leading)

                ShortcutRecorderField(
                    shortcut: $settings.launchpadShortcut,
                    modifierWidth: 190,
                    keyWidth: 100,
                    recordWidth: 76
                )

                ShortcutKeyBadge(shortcut: settings.launchpadShortcut, compact: true)

                Spacer()
            }

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hot corner")
                        .font(.subheadline.weight(.semibold))

                    HotCornerSelector(selection: settings.launchpadHotCorner) { corner in
                        settings.launchpadHotCorner = corner
                    }

                    Text("Move pointer into selected corner to open Launchpad.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 204, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Style")
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 10) {
                        ForEach(LaunchpadStyle.allCases) { style in
                            LaunchpadStyleCard(style: style, isSelected: settings.launchpadStyle == style) {
                                settings.launchpadStyle = style
                            }
                        }
                    }

                    if settings.launchpadStyle == .compact {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Theme")
                                .font(.subheadline.weight(.semibold))

                            HStack(spacing: 10) {
                                ForEach(CompactLaunchpadTheme.allCases) { theme in
                                    ThemeSwatch(theme: theme, isSelected: settings.compactLaunchpadTheme == theme) {
                                        settings.compactLaunchpadTheme = theme
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: settings.launchpadStyle)
    }

    private var filteredApps: [LaunchableApp] {
        let all = launcher.launcherCommands() + launcher.loadSnippets(settings: settings) + launcher.loadApps(settings: settings)
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return all }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.filter {
            $0.name.lowercased().contains(needle)
            || $0.bundleID.lowercased().contains(needle)
            || $0.snippet?.searchText.lowercased().contains(needle) == true
            || matchesLauncherCommand($0, needle: needle)
        }
    }

    private func matchesLauncherCommand(_ app: LaunchableApp, needle: String) -> Bool {
        switch app.id {
        case LauncherCommand.emptyTrash.rawValue:
            return ["empty trash", "vider corbeille", "vider corbeil", "trash"].contains { needle.contains($0) || $0.contains(needle) }
        case LauncherCommand.eject.rawValue:
            return ["eject", "éject", "ejecter"].contains { needle.contains($0) || $0.contains(needle) }
        default:
            return false
        }
    }

    private func shortcutLabel(for shortcut: KeyboardShortcutSetting?) -> String {
        guard let shortcut else { return localizedString("Assign shortcut") }
        return "\(shortcut.modifier.symbolPrefix) \(shortcut.keyDisplayName)"
    }

    private var commandFeedbackPresented: Binding<Bool> {
        Binding(
            get: { commandFeedbackMessage != nil },
            set: { if !$0 { commandFeedbackMessage = nil } }
        )
    }
}

let launchpadDesktopGradient = LinearGradient(
    colors: [Color(red: 0.30, green: 0.47, blue: 0.78), Color(red: 0.16, green: 0.28, blue: 0.52)],
    startPoint: .top, endPoint: .bottom
)

private struct HotCornerSelector: View {
    let selection: LaunchpadHotCorner
    let onSelect: (LaunchpadHotCorner) -> Void
    @State private var hovered: LaunchpadHotCorner?

    private let cornerCases: [LaunchpadHotCorner] = [.topLeft, .topRight, .bottomLeft, .bottomRight]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(launchpadDesktopGradient)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 9)
                Spacer()
            }

            if selection == .disabled {
                Text("Disabled")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.35), in: Capsule())
                    .transition(.opacity)
            }

            cornerZone(.topLeft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cornerZone(.topRight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            cornerZone(.bottomLeft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            cornerZone(.bottomRight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(width: 204, height: 126)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: selection)
        .help("Move pointer into selected corner to open Launchpad.")
    }

    private func cornerZone(_ corner: LaunchpadHotCorner) -> some View {
        let isSelected = selection == corner
        let isHovered = hovered == corner
        return Button {
            onSelect(isSelected ? .disabled : corner)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(zoneFill(selected: isSelected, hovered: isHovered))
                if isSelected {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .padding(6)
        .onHover { hovering in
            hovered = hovering ? corner : (hovered == corner ? nil : hovered)
        }
    }

    private func zoneFill(selected: Bool, hovered: Bool) -> Color {
        if selected { return .accentColor }
        if hovered { return .white.opacity(0.3) }
        return .white.opacity(0.08)
    }
}

private struct LaunchpadStyleCard: View {
    let style: LaunchpadStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                thumbnail
                    .frame(width: 128, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                    )

                HStack(spacing: 4) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    Text(style.title)
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

    @ViewBuilder
    private var thumbnail: some View {
        switch style {
        case .fullscreen:
            ZStack {
                launchpadDesktopGradient
                VStack(spacing: 7) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: 7) {
                            ForEach(0..<5, id: \.self) { column in
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .fill(Color.white.opacity(0.85))
                                    .frame(width: 14, height: 14)
                                    .opacity([0.95, 0.8, 0.9, 0.75, 0.85][column])
                            }
                        }
                    }
                }
            }
        case .compact:
            ZStack {
                launchpadDesktopGradient
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.gray)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 58, height: 5)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(spacing: 3) {
                        resultLine
                        resultLine
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private var resultLine: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 4)
        }
    }
}

private struct ThemeSwatch: View {
    let theme: CompactLaunchpadTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                preview
                    .frame(width: 66, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                    )

                HStack(spacing: 3) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    Text(theme.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        if theme == .glass {
            ZStack {
                LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                Rectangle().fill(.ultraThinMaterial)
                miniSearch(foreground: theme.previewForeground)
            }
        } else {
            ZStack {
                theme.previewBackground
                miniSearch(foreground: theme.previewForeground)
            }
        }
    }

    private func miniSearch(foreground: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(foreground.opacity(0.55))
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(foreground.opacity(0.4))
                    .frame(height: 3)
            }
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(foreground.opacity(0.25))
                .frame(height: 3)
        }
        .padding(.horizontal, 9)
    }
}

private extension CompactLaunchpadTheme {
    var previewBackground: Color {
        switch self {
        case .light: Color(red: 0.96, green: 0.96, blue: 0.97)
        case .dark: Color(red: 0.11, green: 0.11, blue: 0.12)
        case .catpuccin: Color(red: 0.12, green: 0.11, blue: 0.16)
        case .glass: .clear
        }
    }

    var previewForeground: Color {
        switch self {
        case .light: .black
        case .dark: .white
        case .catpuccin: Color(red: 0.95, green: 0.92, blue: 0.97)
        case .glass: .primary
        }
    }
}

struct LaunchShortcutEditor: View {
    let app: LaunchableApp
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var key: String
    @State private var modifier: ShortcutModifierPreset

    init(app: LaunchableApp, settings: AppSettings) {
        self.app = app
        self.settings = settings
        _key = State(initialValue: settings.launchShortcut(for: app.bundleID)?.key ?? "")
        _modifier = State(initialValue: settings.launchShortcut(for: app.bundleID)?.modifier ?? .command)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading) {
                    Text(app.name).font(.headline)
                    Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                }
            }

            ShortcutRecorderField(
                shortcut: shortcutBinding,
                modifierWidth: 190,
                keyWidth: 100,
                recordWidth: 76
            )

            HStack {
                Button("Clear") {
                    settings.setLaunchShortcut(nil, for: app.bundleID)
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    let normalized = normalizedKey(key)
                    guard !normalized.isEmpty else { return }
                    settings.setLaunchShortcut(.init(key: normalized, modifier: modifier), for: app.bundleID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private var shortcutBinding: Binding<KeyboardShortcutSetting> {
        Binding(
            get: {
                KeyboardShortcutSetting(
                    key: normalizedKey(key),
                    modifier: modifier
                )
            },
            set: { shortcut in
                key = shortcut.key
                modifier = shortcut.modifier
            }
        )
    }

    private func normalizedKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.caseInsensitiveCompare("space") == .orderedSame
            || trimmed.caseInsensitiveCompare("espace") == .orderedSame {
            return "space"
        }
        return String(trimmed.suffix(1)).lowercased()
    }

    private func displayKey(_ value: String) -> String {
        value == "space" ? localizedString("Space") : value.uppercased()
    }
}

private struct LaunchpadAppTile: View {
    let app: LaunchableApp

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                if let shortcut = app.shortcut {
                    ShortcutKeyBadge(shortcut: shortcut, compact: true)
                        .offset(x: 8, y: 8)
                }
            }
            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}
