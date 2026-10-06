import SwiftUI

/// Project Library — same pattern as PKMonitor: a featured card for this app
/// plus a grid of the other PK projects, real app icons, screenshots when
/// available and a tinted gradient fallback otherwise.
struct ProjectLibraryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                featuredCard(featured)
                Text(localizedString("More projects"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.top, 6)
                LazyVGrid(columns: gridColumns, spacing: 14) {
                    ForEach(gridProjects) { project in
                        projectCard(project)
                    }
                }
                Link(destination: ProjectLinks.githubProfile) {
                    Label(localizedString("View all repositories on GitHub"), systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString("Project Library"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(localizedString("Discover the other tools and projects I build."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private func featuredCard(_ project: Project) -> some View {
        Link(destination: project.url) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    ProjectIconView(name: project.iconAsset)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

                    Text(project.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(project.kind.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(project.tint))

                    Text(project.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(localizedString("Star on GitHub"), systemImage: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                        .padding(.top, 4)
                }
                .frame(maxWidth: 340, alignment: .leading)
                .padding(22)

                cardMedia(project, iconSize: 96)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 210, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func projectCard(_ project: Project) -> some View {
        Link(destination: project.url) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    cardMedia(project, iconSize: 74)
                }
                .frame(height: 150)
                .clipShape(Rectangle())
                .overlay(alignment: .topLeading) {
                    Text(project.kind.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(10)
                }

                HStack(spacing: 10) {
                    ProjectIconView(name: project.iconAsset)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(project.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// Screenshot when available; otherwise the project's tinted gradient with
    /// its icon centered.
    @ViewBuilder
    private func cardMedia(_ project: Project, iconSize: CGFloat) -> some View {
        if let screenshot = project.screenshot,
           let image = bundledImage(screenshot, subdirectory: "ProjectScreenshots") {
            GeometryReader { proxy in
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(project.tint.withAlphaComponent(0.75)),
                        Color(project.tint.withAlphaComponent(0.35))
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                ProjectIconView(name: project.iconAsset)
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconSize / 5, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            }
        }
    }

    private func bundledImage(_ name: String, subdirectory: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: subdirectory) {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

// MARK: - Model

private struct Project: Identifiable {
    let id: String
    let title: String
    let kind: String
    let description: String
    let iconAsset: String
    let screenshot: String?
    let tint: NSColor
    var url: URL { URL(string: "https://github.com/mondary/\(id)")! }
}

private let projects = [
    Project(
        id: "PKwindowsManagement", title: "PKwindowsManagement", kind: "macOS app",
        description: "Manage windows by keyboard, organize sessions in Rooms and launch installed applications quickly from the menu bar.",
        iconAsset: "PKwindowsManagement", screenshot: nil, tint: NSColor(hex: "#F97316")!
    ),
    Project(
        id: "PKbrain", title: "PKbrain", kind: "macOS app",
        description: "Notes app with inline calculation, command palette, and keyboard-first shortcuts.",
        iconAsset: "PKbrain", screenshot: nil, tint: NSColor(hex: "#6366F1")!
    ),
    Project(
        id: "media-downloader", title: "PKMediaDownloader", kind: "macOS app",
        description: "Video downloader powered by yt-dlp — YouTube, Instagram, X, TikTok and thousands more.",
        iconAsset: "PKMediaDownloader", screenshot: nil, tint: NSColor(hex: "#F43F5E")!
    ),
    Project(
        id: "Macos_PKarchives", title: "PKarchives", kind: "macOS app",
        description: "Archive your Desktop to Google Drive with rclone, using a native macOS interface or CLI/TUI.",
        iconAsset: "PKarchives", screenshot: "PKarchives", tint: NSColor(hex: "#8B5CF6")!
    ),
    Project(
        id: "PKmonitor", title: "PKMonitor", kind: "macOS app",
        description: "CPU, GPU, RAM, network and disk metrics in the menu bar.",
        iconAsset: "PKmonitor", screenshot: "PKmonitor", tint: NSColor(hex: "#0EA5E9")!
    ),
    Project(
        id: "Macos_PKpowerlines", title: "PKpowerlines", kind: "macOS app",
        description: "A native multi-display powerline showing RAM, CPU, network or battery in real time.",
        iconAsset: "PKpowerlines", screenshot: "PKpowerlines", tint: NSColor(hex: "#10B981")!
    ),
    Project(
        id: "PKmac-cleanup", title: "LaunchPad", kind: "macOS app",
        description: "Scan and audit user agents and system daemons with local security analysis.",
        iconAsset: "PKmac-cleanup", screenshot: nil, tint: NSColor(hex: "#EC4899")!
    ),
    Project(
        id: "Chrome_PKshortcuts", title: "PK Chrome Shortcuts", kind: "Chrome extension",
        description: "Control tabs, navigation and split view with keyboard shortcuts.",
        iconAsset: "PKshortcuts", screenshot: nil, tint: NSColor(hex: "#F59E0B")!
    )
]

private var featured: Project { projects[0] }
private var gridProjects: [Project] { Array(projects.dropFirst()) }

// MARK: - Shared pieces

enum ProjectLinks {
    static let githubProfile = URL(string: "https://github.com/mondary")!
}

/// Loads a bundled project icon (Resources/ProjectIcons) with a fallback to
/// the app icon.
struct ProjectIconView: View {
    let name: String

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "ProjectIcons"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                      let icon = NSImage(contentsOf: url) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            }
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6 else { return nil }
        var value: UInt64 = 0
        let scanner = Scanner(string: cleaned)
        guard scanner.scanHexInt64(&value) else { return nil }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
