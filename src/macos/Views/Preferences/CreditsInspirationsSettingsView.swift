import SwiftUI

struct CreditsInspirationsSettingsView: View {
    private struct CreditEntry: Identifiable {
        let id: String
        let author: String
        let roleKey: String
        let license: String
        let iconAsset: String
        let usesTemplateIcon: Bool
        let symbol: String
        let tint: Color
        let url: URL
    }

    // Official project artwork: Sparkle AppIcon from sparkle-project/Sparkle,
    // Laya logo mark from convaiinnovations/laya, Rooms menu icon from rooms.
    private let dependencies = [
        CreditEntry(
            id: "Sparkle",
            author: "Sparkle project",
            roleKey: "Stable and Dev auto-updates.",
            license: "MIT",
            iconAsset: "Sparkle",
            usesTemplateIcon: false,
            symbol: "sparkles",
            tint: Color(red: 0.96, green: 0.68, blue: 0.18),
            url: URL(string: "https://github.com/sparkle-project/Sparkle")!
        ),
        CreditEntry(
            id: "Laya",
            author: "Convai Innovations",
            roleKey: "Local decision model behind the integrated AI.",
            license: "Apache-2.0",
            iconAsset: "Laya",
            usesTemplateIcon: false,
            symbol: "brain.head.profile",
            tint: Color(red: 0.62, green: 0.42, blue: 0.88),
            url: URL(string: "https://huggingface.co/convaiinnovations/laya")!
        )
    ]

    private let inspirations = [
        CreditEntry(
            id: "Rooms",
            author: "Sara Gordić",
            roleKey: "Rooms concept and layout engine, ported as RoomTiler.",
            license: "MIT",
            iconAsset: "Rooms",
            usesTemplateIcon: true,
            symbol: "book.closed.fill",
            tint: Color(red: 0.25, green: 0.62, blue: 0.86),
            url: URL(string: "https://github.com/saragordic/rooms")!
        ),
        CreditEntry(
            id: "Hammerspoon",
            author: "Hammerspoon project",
            roleKey: "Mission Control accessibility and Space-management techniques.",
            license: "MIT",
            iconAsset: "Hammerspoon",
            usesTemplateIcon: false,
            symbol: "slider.horizontal.3",
            tint: Color(red: 0.77, green: 0.43, blue: 0.28),
            url: URL(string: "https://github.com/Hammerspoon/hammerspoon")!
        ),
        CreditEntry(
            id: "yabai",
            author: "koekeishiya",
            roleKey: "SkyLight compatibility techniques for moving windows between Spaces.",
            license: "MIT",
            iconAsset: "yabai",
            usesTemplateIcon: false,
            symbol: "square.3.layers.3d",
            tint: Color(red: 0.29, green: 0.57, blue: 0.76),
            url: URL(string: "https://github.com/asmvik/yabai")!
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                pageHeader
                VStack(alignment: .leading, spacing: 22) {
                    creditGroup(title: localizedString("Tools and dependencies"), entries: dependencies)
                    creditGroup(title: localizedString("Inspirations"), entries: inspirations)
                }
                .frame(maxWidth: 480, alignment: .leading)

                Text(localizedString("Built with Apple's native frameworks: SwiftUI, AppKit and the Accessibility API."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: 480, alignment: .leading)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 36)
            .padding(.top, 36)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private var pageHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Color.accentColor)

            Text(localizedString("Credits"))
                .font(.system(size: 20, weight: .bold))
            Text(localizedString("Projects and tools that inform or power PKwindowsManagement."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func creditGroup(title: String, entries: [CreditEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    creditRow(entry)
                    if index < entries.count - 1 {
                        Divider().padding(.horizontal, 2)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.025)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    private func creditRow(_ entry: CreditEntry) -> some View {
        Link(destination: entry.url) {
            HStack(alignment: .center, spacing: 12) {
                creditIcon(entry)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.id)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(entry.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(localizedString(entry.roleKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(entry.license)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                    .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
            }
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func creditIcon(_ entry: CreditEntry) -> some View {
        let imageURL = Bundle.main.url(forResource: entry.iconAsset, withExtension: "png", subdirectory: "CreditIcons")
        if let imageURL, let image = NSImage(contentsOf: imageURL) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .renderingMode(entry.usesTemplateIcon ? .template : .original)
                .foregroundStyle(entry.tint)
                .scaledToFit()
                .padding(entry.usesTemplateIcon ? 7 : 2)
                .frame(width: 38, height: 38)
                .background(entry.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        } else {
            Image(systemName: entry.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(entry.tint)
                .frame(width: 38, height: 38)
                .background(entry.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }
}
