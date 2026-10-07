import SwiftUI

struct CreditsInspirationsSettingsView: View {
    private struct CreditEntry: Identifiable {
        let id: String
        let author: String
        let roleKey: String
        let license: String
        let url: URL
    }

    private let dependencies = [
        CreditEntry(
            id: "Sparkle",
            author: "Sparkle project",
            roleKey: "Stable and Dev auto-updates.",
            license: "MIT",
            url: URL(string: "https://github.com/sparkle-project/Sparkle")!
        ),
        CreditEntry(
            id: "Laya",
            author: "Convai Innovations",
            roleKey: "Local decision model behind the integrated AI.",
            license: "Apache-2.0",
            url: URL(string: "https://huggingface.co/convaiinnovations/laya")!
        )
    ]

    private let inspirations = [
        CreditEntry(
            id: "Rooms",
            author: "Sara Gordić",
            roleKey: "Rooms concept and layout engine, ported as RoomTiler.",
            license: "MIT",
            url: URL(string: "https://github.com/saragordic/rooms")!
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                creditGroup(title: localizedString("Tools and dependencies"), entries: dependencies)
                creditGroup(title: localizedString("Inspirations"), entries: inspirations)

                Text(localizedString("Built with Apple's native frameworks: SwiftUI, AppKit and the Accessibility API."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedString("Credits & inspirations"))
                .font(.system(size: 24, weight: .bold))
            Text(localizedString("Projects and tools that inform or power PKwindowsManagement."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Link(entry.id, destination: entry.url)
                        .font(.subheadline.weight(.semibold))
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
        .accessibilityElement(children: .combine)
    }
}
