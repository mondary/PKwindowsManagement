import SwiftUI

struct LaunchpadOverlayView: View {
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    private let launcher = AppLauncherService()

    var body: some View {
        let apps = filteredApps
        GeometryReader { geometry in
            ZStack {
                glassPanel(in: geometry.size)

                VStack(spacing: 24) {
                    topBar
                        .padding(.horizontal, 42)
                        .padding(.top, 34)

                    searchField

                    ScrollView {
                        LazyVGrid(columns: gridColumns(for: geometry.size), spacing: 28) {
                            ForEach(apps) { app in
                                Button {
                                    launcher.launch(app, settings: settings)
                                    LaunchpadOverlayController.shared.hide()
                                } label: {
                                    OverlayAppTile(app: app)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, max(54, geometry.size.width * 0.1))
                        .padding(.top, 34)
                        .padding(.bottom, 126)
                    }

                    Spacer(minLength: 0)
                }

                VStack {
                    Spacer()
                    dockStrip(apps: Array(launcher.loadApps(settings: settings).prefix(16)))
                        .padding(.bottom, 28)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                searchFocused = true
            }
        }
        .onExitCommand {
            LaunchpadOverlayController.shared.hide()
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                LaunchpadOverlayController.shared.hide()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.68))
            .background(.white.opacity(0.1), in: Circle())
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .focused($searchFocused)
        }
        .padding(.horizontal, 14)
        .frame(width: 390, height: 38)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func glassPanel(in size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.white.opacity(0.055))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, max(22, size.width * 0.035))
            .padding(.vertical, max(18, size.height * 0.035))
    }

    private func dockStrip(apps: [LaunchableApp]) -> some View {
        HStack(spacing: 14) {
            ForEach(apps.prefix(14)) { app in
                Button {
                    launcher.launch(app, settings: settings)
                    LaunchpadOverlayController.shared.hide()
                } label: {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func gridColumns(for size: CGSize) -> [GridItem] {
        let horizontalInset = max(54, size.width * 0.1) * 2
        let availableWidth = max(420, size.width - horizontalInset)
        let itemWidth: CGFloat = 112
        let count = max(4, min(10, Int(availableWidth / itemWidth)))
        return Array(repeating: GridItem(.fixed(104), spacing: 34), count: count)
    }

    private var filteredApps: [LaunchableApp] {
        let all = launcher.launcherCommands() + launcher.loadApps(settings: settings)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let needle = trimmed.lowercased()
        return all.filter {
            $0.name.lowercased().contains(needle)
            || $0.bundleID.lowercased().contains(needle)
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
        guard let shortcut else { return "" }
        return "\(shortcut.modifier.symbolPrefix) \(shortcut.key.uppercased())"
    }
}

private struct OverlayAppTile: View {
    let app: LaunchableApp

    var body: some View {
        VStack(spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                if let shortcut = app.shortcut {
                    Text(shortcut.modifier.symbolPrefix + shortcut.key.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.78), in: Capsule())
                        .foregroundStyle(.white)
                        .offset(x: 11, y: 7)
                }
            }
            .frame(width: 80, height: 80)
            Text(app.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 104, height: 31, alignment: .top)
        }
        .frame(width: 104, height: 116)
    }
}
