import SwiftUI

/// Persistent links and app metadata shared by every settings section.
struct SettingsFooterView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Link(destination: URL(string: "https://github.com/mondary/PKwindowsManagement")!) {
                Label("GitHub", systemImage: "network")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://github.com/mondary/PKwindowsManagement/issues")!) {
                Label("Issues", systemImage: "exclamationmark.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://ko-fi.com/pouark")!) {
                HStack(spacing: 4) {
                    if let image = AppLocalization.assetImage("kofi-logo") {
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: 12, height: 12)
                    }
                    Text(localizedString("Support me on Ko-fi"))
                }
                .font(.caption)
                .foregroundStyle(Color(red: 1.0, green: 0.37, blue: 0.36))
            }

            Spacer(minLength: 8)

            Text(localizedString("MIT License"))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("·")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("macOS 13+")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
