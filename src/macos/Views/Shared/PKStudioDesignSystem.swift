import AppKit
import SwiftUI

// MARK: - Atelier Glass Palette & Tokens

enum PKStudioPalette {
    static let freeAccent = Color(red: 0.39, green: 0.45, blue: 0.93)
    static let tilingAccent = Color(red: 0.15, green: 0.56, blue: 0.98)
    static let stripAccent = Color(red: 0.07, green: 0.71, blue: 0.66)
    static let roomsAccent = Color(red: 0.58, green: 0.39, blue: 0.96)
    static let switcherAccent = Color(red: 0.95, green: 0.50, blue: 0.23)

    static func color(for mode: WorkspaceWindowMode) -> Color {
        switch mode {
        case .free: freeAccent
        case .tiling: tilingAccent
        case .strip: stripAccent
        }
    }
}

// MARK: - Shared Section Header & Card Chrome

struct PKStudioSectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var tint: Color = .accentColor
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, subtitle: String? = nil, systemImage: String, tint: Color = .accentColor,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.24), tint.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString(title))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                if let subtitle, !subtitle.isEmpty {
                    Text(localizedString(subtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
    }
}

struct PKStudioCard<Content: View>: View {
    var tint: Color? = nil
    var isHighlighted: Bool = false
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    if let tint {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(isHighlighted ? 0.14 : 0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? (tint ?? Color.accentColor).opacity(0.65) : Color.primary.opacity(0.09),
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            )
    }
}

// MARK: - Visual Miniature Monitor for Modes (Free / Tiling / Strip)

struct PKModeGraphicIllustration: View {
    let mode: WorkspaceWindowMode
    var layout: TilingLayoutKind = .focus
    var isSelected: Bool = false

    private var accent: Color { PKStudioPalette.color(for: mode) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(isSelected ? 0.22 : 0.11),
                                Color.primary.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(accent.opacity(isSelected ? 0.55 : 0.22), lineWidth: 1)

                switch mode {
                case .free:
                    freeWindowsCanvas(width: w, height: h)
                case .tiling:
                    tilingWindowsCanvas(width: w, height: h)
                case .strip:
                    stripWindowsCanvas(width: w, height: h)
                }
            }
        }
    }

    private func freeWindowsCanvas(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            miniWindow(accent: accent.opacity(0.45), isPrimary: false)
                .frame(width: w * 0.50, height: h * 0.56)
                .offset(x: w * 0.08, y: h * 0.12)
            miniWindow(accent: accent.opacity(0.55), isPrimary: false)
                .frame(width: w * 0.46, height: h * 0.52)
                .offset(x: w * 0.44, y: h * 0.32)
            miniWindow(accent: accent, isPrimary: true)
                .frame(width: w * 0.54, height: h * 0.60)
                .offset(x: w * 0.22, y: h * 0.20)
        }
    }

    private func tilingWindowsCanvas(width w: CGFloat, height h: CGFloat) -> some View {
        let inset = CGRect(x: 6, y: 6, width: max(12, w - 12), height: max(12, h - 12))
        let effective = layout == .canvas ? .focus : layout
        let frames = TilingLayoutGeometry.frames(kind: effective, count: 4, in: inset, selectedIndex: 0)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(frames.enumerated()), id: \.offset) { idx, rect in
                miniWindow(accent: accent, isPrimary: idx == 0)
                    .frame(width: max(8, rect.width - 2), height: max(8, rect.height - 2))
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }

    private func stripWindowsCanvas(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Top minimap pill (OmniWM / OpenCanvas signature)
            HStack(spacing: 3) {
                Capsule().fill(accent.opacity(0.35)).frame(width: 8, height: 3)
                Capsule().fill(accent).frame(width: 12, height: 3)
                Capsule().fill(accent).frame(width: 12, height: 3)
                Capsule().fill(accent.opacity(0.35)).frame(width: 8, height: 3)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.regularMaterial, in: Capsule())
            .frame(maxWidth: .infinity)
            .offset(y: 5)

            let topY: CGFloat = 17
            let contentH = max(14, h - topY - 6)
            let colW = (w - 28) * 0.46

            // Left parked sliver
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.28))
                .frame(width: 5, height: contentH)
                .offset(x: 4, y: topY)

            // Active full-height column
            miniWindow(accent: accent, isPrimary: true)
                .frame(width: colW, height: contentH)
                .offset(x: 12, y: topY)

            // Paired half-height column
            VStack(spacing: 3) {
                miniWindow(accent: accent, isPrimary: false)
                    .frame(width: colW, height: (contentH - 3) / 2)
                miniWindow(accent: accent, isPrimary: false)
                    .frame(width: colW, height: (contentH - 3) / 2)
            }
            .offset(x: 15 + colW, y: topY)

            // Right parked sliver
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.28))
                .frame(width: 5, height: contentH)
                .offset(x: w - 9, y: topY)
        }
    }

    private func miniWindow(accent: Color, isPrimary: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(
                isPrimary
                    ? accent.opacity(0.34)
                    : Color(nsColor: .windowBackgroundColor).opacity(0.92)
            )
            .overlay(alignment: .topLeading) {
                HStack(spacing: 2.5) {
                    Circle().fill(accent.opacity(isPrimary ? 0.95 : 0.45)).frame(width: 3.5, height: 3.5)
                    Circle().fill(accent.opacity(isPrimary ? 0.65 : 0.30)).frame(width: 3.5, height: 3.5)
                }
                .padding(4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(accent.opacity(isPrimary ? 0.85 : 0.35), lineWidth: isPrimary ? 1.2 : 0.8)
            )
    }
}

// MARK: - Large Visual Mode Card (Free / Tiling / Strip)

struct PKModeSelectorCard: View {
    let mode: WorkspaceWindowMode
    let activeLayout: TilingLayoutKind
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    private var accent: Color { PKStudioPalette.color(for: mode) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                PKModeGraphicIllustration(mode: mode, layout: activeLayout, isSelected: isSelected)
                    .frame(height: 76)

                HStack(spacing: 6) {
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? accent : .secondary)
                    Text(mode.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? accent : Color.secondary.opacity(0.45))
                }

                Text(mode.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? accent.opacity(0.75) : Color.primary.opacity(0.10),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

// MARK: - Per-Display Card (Écran par écran)

struct PKDisplayWorkspaceCard: View {
    let snapshot: TilingWorkspaceSnapshot
    let isFocusedDisplay: Bool
    let activeRoomName: String?
    let onSelectDisplay: () -> Void
    let onSelectMode: (WorkspaceWindowMode) -> Void

    private var currentMode: WorkspaceWindowMode { snapshot.profile.workspaceMode }
    private var accent: Color { PKStudioPalette.color(for: currentMode) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onSelectDisplay) {
                HStack(spacing: 8) {
                    Image(systemName: "display")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(snapshot.displayName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    if isFocusedDisplay {
                        Text(localizedString("Active"))
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent.opacity(0.16), in: Capsule())
                            .foregroundStyle(accent)
                    }
                    Spacer(minLength: 4)
                    if let activeRoomName {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.3.group")
                                .font(.system(size: 9, weight: .semibold))
                            Text(activeRoomName)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(PKStudioPalette.roomsAccent.opacity(0.15), in: Capsule())
                        .foregroundStyle(PKStudioPalette.roomsAccent)
                    }
                }
            }
            .buttonStyle(.plain)

            PKModeGraphicIllustration(
                mode: currentMode,
                layout: snapshot.profile.effectiveTilingLayout,
                isSelected: isFocusedDisplay
            )
            .frame(height: 62)
            .onTapGesture(perform: onSelectDisplay)

            HStack(spacing: 4) {
                ForEach(WorkspaceWindowMode.allCases) { mode in
                    let active = currentMode == mode
                    let modeColor = PKStudioPalette.color(for: mode)
                    Button {
                        onSelectMode(mode)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.symbolName)
                                .font(.system(size: 9.5, weight: .semibold))
                            Text(mode.shortTitle)
                                .font(.system(size: 10.5, weight: active ? .bold : .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(active ? modeColor.opacity(0.20) : Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(active ? modeColor.opacity(0.75) : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(active ? modeColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 248)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocusedDisplay ? accent.opacity(0.08) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isFocusedDisplay ? accent.opacity(0.65) : Color.primary.opacity(0.10),
                              lineWidth: isFocusedDisplay ? 1.5 : 1)
        )
    }
}

// MARK: - Visual Tiling Layout Tile (7 Layouts Gallery)

struct PKTilingLayoutTile: View {
    let layout: TilingLayoutKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                GeometryReader { geo in
                    let area = CGRect(x: 4, y: 4, width: max(10, geo.size.width - 8), height: max(10, geo.size.height - 8))
                    let frames = TilingLayoutGeometry.frames(kind: layout, count: 4, in: area, selectedIndex: 0)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        PKStudioPalette.tilingAccent.opacity(isSelected ? 0.22 : 0.08),
                                        Color.primary.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isSelected ? PKStudioPalette.tilingAccent.opacity(0.65) : Color.primary.opacity(0.12),
                                lineWidth: 1
                            )
                        ForEach(Array(frames.enumerated()), id: \.offset) { idx, rect in
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(
                                    idx == 0
                                        ? PKStudioPalette.tilingAccent.opacity(0.42)
                                        : Color(nsColor: .windowBackgroundColor).opacity(0.88)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                        .strokeBorder(
                                            PKStudioPalette.tilingAccent.opacity(idx == 0 ? 0.90 : 0.35),
                                            lineWidth: idx == 0 ? 1.1 : 0.7
                                        )
                                )
                                .overlay {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(idx == 0 ? PKStudioPalette.tilingAccent : .secondary)
                                }
                                .frame(width: max(6, rect.width - 2), height: max(6, rect.height - 2))
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
                .frame(height: 58)

                HStack(spacing: 4) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? PKStudioPalette.tilingAccent : .secondary)
                    Text(layout.title)
                        .font(.system(size: 11.5, weight: isSelected ? .bold : .medium, design: .rounded))
                        .lineLimit(1)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? PKStudioPalette.tilingAccent.opacity(0.12) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? PKStudioPalette.tilingAccent.opacity(0.75) : Color.primary.opacity(0.08),
                                  lineWidth: isSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Screen-Inset Margin Studio (replaces raw % text fields)

struct PKVisualMarginStudio: View {
    let title: String
    let subtitle: String
    @Binding var margins: WindowMargins
    var tint: Color = PKStudioPalette.freeAccent

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            // Live miniature screen showing the exact inset margins
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let topInset = h * (margins.top / 100.0)
                let bottomInset = h * (margins.bottom / 100.0)
                let leftInset = w * (margins.left / 100.0)
                let rightInset = w * (margins.right / 100.0)
                let innerW = max(16, w - leftInset - rightInset - 12)
                let innerH = max(14, h - topInset - bottomInset - 12)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint.opacity(0.24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(tint.opacity(0.85), lineWidth: 1.2)
                        )
                        .overlay {
                            Text("\(Int(margins.top))·\(Int(margins.bottom))·\(Int(margins.left))·\(Int(margins.right))%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(tint)
                        }
                        .frame(width: innerW, height: innerH)
                        .offset(x: 6 + leftInset, y: 6 + topInset)
                }
            }
            .frame(width: 146, height: 94)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(localizedString(title))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text(localizedString(subtitle))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if margins != .zero {
                        Button(localizedString("0%")) {
                            margins = .zero
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 6) {
                    marginSlider(label: "Top", icon: "arrow.up.to.line", value: $margins.top)
                    marginSlider(label: "Bottom", icon: "arrow.down.to.line", value: $margins.bottom)
                    marginSlider(label: "Left", icon: "arrow.left.to.line", value: $margins.left)
                    marginSlider(label: "Right", icon: "arrow.right.to.line", value: $margins.right)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func marginSlider(label: String, icon: String, value: Binding<CGFloat>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 14)
            Text(localizedString(label))
                .font(.system(size: 10.5, weight: .medium))
                .frame(width: 44, alignment: .leading)
                .lineLimit(1)
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: { value.wrappedValue = $0.rounded() }
            ), in: 0...25, step: 1)
            .controlSize(.small)
            Text("\(Int(value.wrappedValue))%")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

// MARK: - Overlay Mode Switcher Bar (Used in Rooms Switcher, CMD+Tab, Spotlight)

struct PKOverlayModeSwitcherBar: View {
    @ObservedObject private var canvas = HorizontalCanvasService.shared
    var onCaptureRoom: (() -> Void)? = nil

    private var currentMode: WorkspaceWindowMode {
        canvas.currentWorkspace?.profile.workspaceMode ?? .free
    }

    var body: some View {
        HStack(spacing: 8) {
            if let ws = canvas.currentWorkspace {
                HStack(spacing: 5) {
                    Image(systemName: "display")
                        .font(.system(size: 11, weight: .semibold))
                    Text(ws.displayName)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.primary.opacity(0.06), in: Capsule())
            }

            HStack(spacing: 4) {
                ForEach(WorkspaceWindowMode.allCases) { mode in
                    let active = currentMode == mode
                    let color = PKStudioPalette.color(for: mode)
                    Button {
                        canvas.setWorkspaceMode(mode)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.symbolName)
                                .font(.system(size: 10.5, weight: .semibold))
                            Text(mode.shortTitle)
                                .font(.system(size: 11, weight: active ? .bold : .medium, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(active ? color.opacity(0.22) : Color.primary.opacity(0.05))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(active ? color.opacity(0.75) : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(active ? color : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if currentMode == .tiling {
                Menu {
                    ForEach(TilingLayoutKind.tilingCases) { layout in
                        Button {
                            canvas.setTilingLayout(layout)
                        } label: {
                            HStack {
                                Text(layout.title)
                                if canvas.currentWorkspace?.profile.effectiveTilingLayout == layout {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 10, weight: .semibold))
                        Text(canvas.currentWorkspace?.profile.effectiveTilingLayout.title ?? localizedString("Auto"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(PKStudioPalette.tilingAccent.opacity(0.14), in: Capsule())
                    .foregroundStyle(PKStudioPalette.tilingAccent)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Spacer(minLength: 4)

            if let onCaptureRoom {
                Button(action: onCaptureRoom) {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 11, weight: .semibold))
                        Text(localizedString("Save screen as Room"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PKStudioPalette.roomsAccent.opacity(0.16), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(PKStudioPalette.roomsAccent.opacity(0.55), lineWidth: 1)
                    )
                    .foregroundStyle(PKStudioPalette.roomsAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            canvas.refreshCurrentWorkspace()
        }
    }
}
