import SwiftUI

struct StoreApp: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let url: String
    let color: Color
}

struct StoreSettingsView: View {
    private let apps: [StoreApp] = [
        StoreApp(
            name: "PKbrain",
            description: localizedString("Notes app with inline calculation, command palette, and keyboard-first shortcuts."),
            icon: "note.text",
            url: "https://github.com/mondary/PKbrain",
            color: .indigo
        ),
        StoreApp(
            name: "PKMediaDownloader",
            description: localizedString("Video downloader powered by yt-dlp — YouTube, Instagram, X, TikTok and thousands more."),
            icon: "arrow.down.circle",
            url: "https://github.com/mondary/media-downloader",
            color: .red
        ),
        StoreApp(
            name: "PKarchives",
            description: localizedString("Archive your Desktop to Google Drive via rclone."),
            icon: "externaldrive.badge.icloud",
            url: "https://github.com/mondary/Macos_PKarchives",
            color: .teal
        ),
        StoreApp(
            name: "PKpowerlines",
            description: localizedString("Menu bar app showing a real-time RAM or battery bar on every screen."),
            icon: "waveform.path.ecg",
            url: "https://github.com/mondary/Macos_PKpowerlines",
            color: .green
        ),
        StoreApp(
            name: "PKMonitor",
            description: localizedString("A focused system monitor in the menu bar."),
            icon: "speedometer",
            url: "https://github.com/mondary/PKmonitor",
            color: .orange
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 36)
                    .padding(.bottom, 24)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(apps) { app in
                        appCard(app)
                    }
                }
                .frame(maxWidth: 640)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "bag.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)

            Text(localizedString("More Apps by PK"))
                .font(.system(size: 20, weight: .bold))

            Text(localizedString("Check out other apps from the same developer"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func appCard(_ app: StoreApp) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(app.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: app.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(app.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(app.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Link(destination: URL(string: app.url)!) {
                Text(localizedString("Get"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(app.color)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
