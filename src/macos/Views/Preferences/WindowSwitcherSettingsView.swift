import AppKit
import SwiftUI

/// Visual studio for CMD+Tab / Window Switcher settings (zero text-wall form).
struct WindowSwitcherSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var previewSelectedCard: Int = 1
    @State private var previewFilterDemo: Bool = false
    @State private var confirmReleaseGesture = false

    private var accent: Color { PKStudioPalette.switcherAccent }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PKStudioSectionHeader(
                    title: "CMD+Tab & Window Switcher",
                    subtitle: "Visual window previews, running apps and Rooms in a single keyboard-first stage.",
                    systemImage: "rectangle.on.rectangle.angled",
                    tint: accent
                ) {
                    HStack(spacing: 10) {
                        Button {
                            WindowSwitcherController.shared.requestPreviews()
                        } label: {
                            Label(localizedString("Enable previews…"), systemImage: "camera.metering.matrix")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            WindowSwitcherController.shared.show()
                        } label: {
                            Label(localizedString("Open Window Previews"), systemImage: "sparkles.rectangle.stack")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                    }
                }

                liveInteractiveSwitcherStage

                HStack(alignment: .top, spacing: 16) {
                    activationModeStudioCard
                    filterBehaviorStudioCard
                }

                HStack(alignment: .top, spacing: 16) {
                    shortcutAndPermissionsCard
                    keyboardGesturesGalleryCard
                }
            }
            .padding(24)
        }
    }

    // MARK: - 1. Live Interactive Preview Stage

    private var liveInteractiveSwitcherStage: some View {
        PKStudioCard(tint: accent, isHighlighted: true, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(accent)
                        Text(localizedString("Interactive Switcher Stage"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }

                    Text(settings.windowSwitcherUsesCommandTab ? "⌘Tab + ⌃⌥Tab" : "⌃⌥Tab")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.16), in: Capsule())
                        .foregroundStyle(accent)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            previewFilterDemo.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10, weight: .bold))
                            Text(previewFilterDemo ? localizedString("Filter: “Safari”") : localizedString("Simulate filter"))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(previewFilterDemo ? accent.opacity(0.22) : Color.primary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Miniature replica of the Atelier Glass Window Switcher
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        scopeBadge(icon: "macwindow", title: localizedString("Windows"), count: 3, active: true)
                        scopeBadge(icon: "square.grid.2x2", title: localizedString("Applications"), count: 4, active: false)
                        scopeBadge(icon: "rectangle.3.group", title: "Rooms", count: 2, active: false)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(previewFilterDemo ? "Safari" : localizedString("Search windows, apps or rooms"))
                                .font(.system(size: 11))
                                .foregroundStyle(previewFilterDemo ? .primary : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                    }

                    HStack(spacing: 12) {
                        previewWindowTile(
                            index: 0,
                            badge: "⌘1",
                            app: "Xcode / Code",
                            title: "PKwindowsManagement — Studio.swift",
                            tint: PKStudioPalette.tilingAccent,
                            darkCanvas: true
                        )
                        previewWindowTile(
                            index: 1,
                            badge: "⌘2",
                            app: "Safari",
                            title: "Apple Human Interface Guidelines",
                            tint: accent,
                            darkCanvas: false
                        )
                        previewWindowTile(
                            index: 2,
                            badge: "⌘3",
                            app: "Terminal",
                            title: "swift build --sdk MacOSX26.5",
                            tint: PKStudioPalette.stripAccent,
                            darkCanvas: true
                        )
                    }

                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            ForEach(["calendar", "music.note", "waveform.path.ecg", "terminal"], id: \.self) { sym in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                    Image(systemName: sym)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 30, height: 30)
                            }
                        }

                        Divider().frame(height: 22)

                        HStack(spacing: 8) {
                            miniRoomPill(name: "Studio", layout: "Focus", tint: PKStudioPalette.roomsAccent)
                            miniRoomPill(name: "Research", layout: "Strip", tint: PKStudioPalette.stripAccent)
                        }

                        Spacer()

                        Text(
                            previewFilterDemo && settings.windowSwitcherStickyCommandTab
                                ? localizedString("Filter active → press ↵ Return to open")
                                : localizedString("Release ⌘ or press ↵ Return to activate")
                        )
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    private func scopeBadge(icon: String, title: String, count: Int, active: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(active ? accent.opacity(0.18) : Color.primary.opacity(0.04))
        )
        .foregroundStyle(active ? accent : .secondary)
    }

    private func previewWindowTile(index: Int, badge: String, app: String, title: String,
                                   tint: Color, darkCanvas: Bool) -> some View {
        let selected = previewSelectedCard == index
        let dimmed = previewFilterDemo && index != 1
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                previewSelectedCard = index
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(darkCanvas ? Color.black.opacity(0.78) : Color(nsColor: .windowBackgroundColor))
                        .frame(height: 82)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(badge)
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.55), in: Capsule())
                            Spacer()
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(4)
                                .background(Color.black.opacity(0.45), in: Circle())
                        }
                        RoundedRectangle(cornerRadius: 2).fill(tint.opacity(0.75)).frame(width: 78, height: 4)
                        RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.32)).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.22)).frame(width: 110, height: 4)
                    }
                    .padding(8)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(selected ? accent : Color.primary.opacity(0.12),
                                      lineWidth: selected ? 2 : 1)
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(app)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .opacity(dimmed ? 0.35 : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func miniRoomPill(name: String, layout: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(tint)
            Text(name)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            Text(layout)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: - 2. Activation Mode Card (⌘Tab vs Dedicated Shortcut)

    private var activationModeStudioCard: some View {
        PKStudioCard(tint: accent) {
            VStack(alignment: .leading, spacing: 12) {
                Label(localizedString("Trigger Mode"), systemImage: "command.square.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    visualChoiceTile(
                        title: localizedString("Replace ⌘Tab"),
                        subtitle: localizedString("Hold ⌘ + Tab for visual window thumbnails"),
                        isSelected: settings.windowSwitcherUsesCommandTab,
                        keys: ["⌘", "⇥"]
                    ) {
                        settings.windowSwitcherUsesCommandTab = true
                    }

                    visualChoiceTile(
                        title: localizedString("Keep macOS ⌘Tab"),
                        subtitle: localizedString("Use only the dedicated shortcut (⌃⌥Tab)"),
                        isSelected: !settings.windowSwitcherUsesCommandTab,
                        keys: ["⌃", "⌥", "⇥"]
                    ) {
                        settings.windowSwitcherUsesCommandTab = false
                    }
                }
            }
        }
    }

    // MARK: - 3. Filter Validation Card (Sticky vs Instant Release)

    private var filterBehaviorStudioCard: some View {
        PKStudioCard(tint: PKStudioPalette.tilingAccent) {
            VStack(alignment: .leading, spacing: 12) {
                Label(localizedString("When typing a search filter"), systemImage: "magnifyingglass.circle.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    visualChoiceTile(
                        title: localizedString("Confirm with ↵ Return"),
                        subtitle: localizedString("Keeps the panel open while typing a filter"),
                        isSelected: settings.windowSwitcherStickyCommandTab,
                        keys: ["A…Z", "↵"],
                        tint: PKStudioPalette.tilingAccent
                    ) {
                        settings.windowSwitcherStickyCommandTab = true
                    }

                    visualChoiceTile(
                        title: localizedString("Activate on ⌘ release"),
                        subtitle: localizedString("Releasing ⌘ immediately opens the top match"),
                        isSelected: !settings.windowSwitcherStickyCommandTab,
                        keys: ["⌘ ↑"],
                        tint: PKStudioPalette.tilingAccent
                    ) {
                        settings.windowSwitcherStickyCommandTab = false
                    }
                }
                .disabled(!settings.windowSwitcherUsesCommandTab)
                .opacity(settings.windowSwitcherUsesCommandTab ? 1 : 0.55)
            }
        }
    }

    private func visualChoiceTile(title: String, subtitle: String, isSelected: Bool,
                                  keys: [String], tint: Color? = nil,
                                  action: @escaping () -> Void) -> some View {
        let activeTint = tint ?? accent
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(keys, id: \.self) { key in
                        Text(key)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSelected ? activeTint.opacity(0.22) : Color.primary.opacity(0.07))
                            )
                            .foregroundStyle(isSelected ? activeTint : .primary)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? activeTint : .secondary)
                }

                Text(title)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? activeTint.opacity(0.11) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isSelected ? activeTint.opacity(0.75) : Color.primary.opacity(0.09),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. Dedicated Shortcut & Screen Recording Card

    private var shortcutAndPermissionsCard: some View {
        PKStudioCard(tint: PKStudioPalette.freeAccent) {
            VStack(alignment: .leading, spacing: 14) {
                Label(localizedString("Direct Shortcut & Thumbnails"), systemImage: "keyboard.badge.eye")
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedString("Open Window Previews"))
                            .font(.system(size: 12.5, weight: .semibold))
                        Text(localizedString("Works anytime, even when ⌘Tab stays on macOS"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CompactShortcutField(shortcut: Binding(
                        get: { settings.shortcut(for: .windowSwitcherToggle) },
                        set: { value in
                            if let value { settings.setShortcut(value, for: .windowSwitcherToggle) }
                            else { settings.clearShortcut(for: .windowSwitcherToggle) }
                        }
                    ))
                    Button {
                        settings.resetShortcut(for: .windowSwitcherToggle)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(localizedString("Reset"))
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                exposeShortcutRow
                exposeGestureRow

                HStack(spacing: 12) {
                    Image(systemName: "photo.badge.checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PKStudioPalette.freeAccent)
                        .frame(width: 32, height: 32)
                        .background(PKStudioPalette.freeAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedString("Live Window Thumbnails"))
                            .font(.system(size: 12.5, weight: .semibold))
                        Text(localizedString("Captured on demand in memory via ScreenCaptureKit."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(localizedString("Enable previews…")) {
                        WindowSwitcherController.shared.requestPreviews()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var exposeShortcutRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { WindowSwitcherController.shared.showExpose() } label: {
                    Label(localizedString("Open Exposé PK"), systemImage: "rectangle.split.3x1")
                }
                .buttonStyle(.bordered)
                Spacer(minLength: 8)
                CompactShortcutField(shortcut: Binding(
                    get: { settings.shortcut(for: .windowExposeToggle) },
                    set: { value in
                        if let value { settings.setShortcut(value, for: .windowExposeToggle) }
                        else { settings.clearShortcut(for: .windowExposeToggle) }
                    }
                ))
                Button { settings.resetShortcut(for: .windowExposeToggle) } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .help(localizedString("Reset"))
            }
            Text(localizedString("Try the fullscreen Exposé with Ctrl + Option + E: windows animate over your wallpaper. Trackpad gestures stay unchanged."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Optional native four-finger upward swipe. macOS owns that gesture by
    /// default (Mission Control), so the row explains how to release it.
    private var exposeGestureRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { settings.exposeTrackpadGesture },
                set: { settings.exposeTrackpadGesture = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedString("Four-finger swipe up"))
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(localizedString("Opens Exposé PK instead of doing nothing"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            Text(localizedString("macOS keeps four-finger swipes for Mission Control. To make Exposé PK the only response, release that system gesture once in System Settings → Trackpad → More Gestures."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(localizedString("Open Trackpad settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button(localizedString("Release the gesture…")) { confirmReleaseGesture = true }
                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .alert(localizedString("Release the Mission Control gesture?"), isPresented: $confirmReleaseGesture) {
            Button(localizedString("Cancel"), role: .cancel) {}
            Button(localizedString("Release the gesture"), role: .destructive) { releaseSystemSwipe() }
        } message: {
            Text(localizedString("This disables the four-finger vertical swipe in macOS Trackpad settings. Mission Control remains available from its keyboard shortcut and the menu bar. A logout may be required."))
        }
    }

    /// Explicit, confirmed change of a macOS preference (never silent).
    private func releaseSystemSwipe() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.apple.AppleMultitouchTrackpad",
                             "TrackpadFourFingerVertSwipeGesture", "-int", "0"]
        try? process.run()
    }

    // MARK: - 5. Visual Keyboard Gestures Grid

    private var keyboardGesturesGalleryCard: some View {
        PKStudioCard(tint: PKStudioPalette.roomsAccent) {
            VStack(alignment: .leading, spacing: 12) {
                Label(localizedString("Built-in Switcher Shortcuts"), systemImage: "sparkles")
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    gestureTile(keys: "⌘1–9", title: localizedString("Direct jump"), icon: "bolt.fill")
                    gestureTile(keys: "↑ ↓ ← →", title: localizedString("2D Grid navigation"), icon: "arrow.up.and.down.and.arrow.left.and.right")
                    gestureTile(keys: "⌘W", title: localizedString("Close window"), icon: "xmark.circle.fill")
                    gestureTile(keys: "⌘Q", title: localizedString("Quit app"), icon: "power")
                    gestureTile(keys: "⌘N", title: localizedString("New Room"), icon: "plus.rectangle.on.rectangle")
                    gestureTile(keys: "⌥⇥", title: localizedString("Next Room"), icon: "rectangle.3.group")
                }
            }
        }
    }

    private func gestureTile(keys: String, title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PKStudioPalette.roomsAccent)
                .frame(width: 22, height: 22)
                .background(PKStudioPalette.roomsAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(keys)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
