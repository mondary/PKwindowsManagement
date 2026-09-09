import SwiftUI

struct SupportSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 36)
                    .padding(.bottom, 24)

                VStack(spacing: 16) {
                    coffeeCard
                    linksCard
                }
                .frame(maxWidth: 480)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)

            Text(localizedString("Support PKwindowsManagement"))
                .font(.system(size: 20, weight: .bold))

            Text(localizedString("If you enjoy using this app, consider supporting its development."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var coffeeCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                kofiIcon
                    .resizable()
                    .frame(width: 28, height: 28)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ko-fi")
                        .font(.system(size: 14, weight: .semibold))
                    Text(localizedString("Support the developer with a coffee"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Link(destination: URL(string: "https://ko-fi.com/pouark")!) {
                    Text(localizedString("Donate"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(red: 1.0, green: 0.37, blue: 0.36))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var kofiIcon: Image {
        if let image = AppLocalization.assetImage("kofi-logo") {
            return Image(nsImage: image)
        }
        return Image(systemName: "cup.and.saucer.fill")
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            linkRow(
                icon: "network",
                title: "GitHub",
                subtitle: localizedString("Source code and releases"),
                url: "https://github.com/mondary/PKwindowsManagement"
            )
            Divider().padding(.leading, 52)
            linkRow(
                icon: "exclamationmark.bubble",
                title: localizedString("Report an Issue"),
                subtitle: localizedString("Bugs, feature requests, feedback"),
                url: "https://github.com/mondary/PKwindowsManagement/issues"
            )
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func linkRow(icon: String, title: String, subtitle: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
