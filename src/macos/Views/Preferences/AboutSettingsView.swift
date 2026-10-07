import SwiftUI

struct AboutSettingsView: View {
    @ObservedObject private var updater = UpdaterManager.shared
    @State private var selectedChannel = UpdaterManager.shared.channel

    private let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    private let appBuild = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "—"

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    appIconLarge
                        .padding(.top, 36)
                        .padding(.bottom, 16)

                    Text("PKwindowsManagement")
                        .font(.system(size: 24, weight: .bold))

                    Text("Version \(appVersion) (\(appBuild))")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    Text(localizedString("By PK"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                        .padding(.bottom, 32)

                    aboutText
                        .frame(maxWidth: 480)
                        .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            updateSection
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            selectedChannel = updater.channel
            updater.refreshAvailableVersions()
        }
        .onChange(of: selectedChannel) { channel in
            updater.channel = channel
        }
    }

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(localizedString("Updates"))
                        .font(.headline)

                    Picker(localizedString("Update channel"), selection: $selectedChannel) {
                        ForEach(UpdateChannel.allCases) { channel in
                            Text(channel.title).tag(channel)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel(localizedString("Update channel"))
                    .frame(width: 190)

                    Text(selectedChannel.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 220, alignment: .leading)

                HStack(alignment: .top, spacing: 0) {
                    versionColumn(
                        title: localizedString("Stable version"),
                        value: updater.latestStableVersion ?? localizedString("Not published"),
                        symbol: "checkmark.seal",
                        isInstalled: !isDevBuild
                    )
                    Divider().frame(height: 42)
                    versionColumn(
                        title: localizedString("Dev version"),
                        value: updater.latestDevVersion ?? localizedString("Not published"),
                        symbol: "hammer",
                        isInstalled: isDevBuild
                    )
                }
                .frame(maxWidth: .infinity)
            }

            HStack {
                Spacer(minLength: 0)
                Button {
                    updater.checkForUpdatesOrSwitch()
                } label: {
                    Label(localizedString("Check for Updates…"), systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .disabled(updater.installingSwitch)
            }

            if updater.installingSwitch {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localizedString("Installing update…"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let message = updater.switchErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .alert(localizedString("Switch channel?"), isPresented: switchOfferPresented) {
            Button(localizedString("Install and relaunch")) { updater.performSwitchInstall() }
            Button(localizedString("Cancel"), role: .cancel) { updater.cancelSwitchOffer() }
        } message: {
            if let offer = updater.switchOffer {
                Text(String(
                    format: localizedString("You are using %1$@. Install %2$@ from the %3$@ channel?"),
                    appVersion, offer.version, offer.channel.title
                ))
            }
        }
    }

    private func versionColumn(title: String, value: String, symbol: String, isInstalled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .help(value)
            if isInstalled {
                Label(localizedString("Installed version"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.green)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private var isDevBuild: Bool {
        appVersion.localizedCaseInsensitiveContains("-dev")
    }

    private var switchOfferPresented: Binding<Bool> {
        Binding(
            get: { updater.switchOffer != nil },
            set: { if !$0 { updater.cancelSwitchOffer() } }
        )
    }

    private var appIconLarge: some View {
        Group {
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let icon = NSImage(contentsOf: url)
            {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
            } else {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var aboutText: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localizedString("Hi friend,"))
                .italic()
                .font(.system(size: 13))

            Text(localizedString("PKwindowsManagement was born from a simple frustration: managing windows and launching apps without cluttering the screen."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text(localizedString("Window snapping, compact or fullscreen launchpad, script snippets, app shortcuts — all from the keyboard, without leaving your flow. Multi-display, native binary, zero dependencies."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text(localizedString("Built with care for the Mac community. Unobtrusive when you don't need it, there when you look at it."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text(localizedString("Thanks for being part of this."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Text("— PK")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
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
            Spacer()
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
    }
}
