import SwiftUI

/// Full-display composition: wallpaper, freely positioned window replicas and
/// floating labels. Islands or a full-screen strip; no enclosing panel frame.
struct ExposeView: View {
    @ObservedObject var model: WindowSwitcherModel
    @ObservedObject var scene: ExposeScene
    let screen: ExposeScene.Screen
    let onActivate: (WindowSwitcherID) -> Void
    let onClose: () -> Void
    @FocusState private var searchFocused: Bool

    private var primary: Bool { screen.id == scene.activeID }
    private var decorationsVisible: Bool { scene.expanded && !scene.dismissing }
    private var canAct: Bool { model.selectedID != nil && !model.isBusy && !scene.dismissing }

    var body: some View {
        ZStack(alignment: .topLeading) {
            wallpaper
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
            windowLayer
            if primary {
                floatingControls.zIndex(10000)
                if model.isLoading {
                    ProgressView().controlSize(.large).position(x: screen.frame.width / 2, y: screen.frame.height / 2)
                        .zIndex(10001)
                } else if scene.overview.windows.isEmpty {
                    Text(localizedString("No matching windows"))
                        .font(.title2.weight(.medium)).foregroundStyle(.white)
                        .position(x: screen.frame.width / 2, y: screen.frame.height / 2)
                        .opacity(decorationsVisible ? 1 : 0)
                }
            } else {
                Text(localizedString("All windows are grouped on the display where Exposé was opened."))
                    .font(.callout).foregroundStyle(.white.opacity(0.8))
                    .padding(12).background(.ultraThinMaterial, in: Capsule())
                    .position(x: screen.frame.width / 2, y: screen.frame.height - 42)
                    .opacity(decorationsVisible ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: screen.frame.width, height: screen.frame.height)
        .clipped()
        .preferredColorScheme(.dark)
        .onChange(of: model.query) { _ in updateLayout() }
        .onChange(of: model.items) { _ in updateLayout() }
        .onChange(of: model.message) { _ in updateLayout() }
        .onChange(of: model.selectedID) { id in
            guard primary, scene.mode == .strip else { return }
            withAnimation(scene.reduceMotion ? nil : .easeOut(duration: 0.18)) { scene.reveal(id) }
        }
        .onChange(of: scene.expanded) { expanded in
            if primary && expanded { searchFocused = true }
        }
    }

    private var windowLayer: some View {
        ZStack(alignment: .topLeading) {
            // Islands: one readable card per app group — background, title
            // INSIDE the card, tight preview gaps. No free-floating labels.
            if scene.mode == .islands {
                ForEach(scene.overview.headings) { groupCard($0) }
            }
            ForEach(scene.overview.headings) { appHeading($0) }
            ForEach(Array(scene.overview.windows.enumerated()), id: \.element.id) { index, placement in
                windowReplica(placement)
                    .zIndex(Double(model.items.count - (model.items.firstIndex { $0.id == placement.id } ?? index)))
                caption(placement).zIndex(Double(model.items.count + 1))
            }
        }
        .frame(width: screen.frame.width, height: screen.frame.height)
        .mask {
            let clip = scene.mode == .strip && scene.expanded
            let area = clip ? (primary ? ExposeLayout.local(scene.availableArea, on: screen.frame)
                : CGRect(x: -10000, y: -10000, width: 1, height: 1))
                : CGRect(origin: .zero, size: screen.frame.size)
            Rectangle().frame(width: area.width, height: area.height).position(x: area.midX, y: area.midY)
        }
    }

    private var wallpaper: some View {
        ZStack {
            Color(nsColor: screen.fill)
            if let image = scene.wallpapers[screen.id] {
                if screen.fitWallpaper {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    Image(nsImage: image).resizable().scaledToFill()
                }
            }
        }
        .frame(width: screen.frame.width, height: screen.frame.height)
        .clipped()
        .overlay(Color.black.opacity(0.2))
        .opacity(scene.expanded ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func windowReplica(_ placement: ExposeLayout.Placement) -> some View {
        let item = placement.item
        let target = ExposeLayout.local(scene.displayed(placement.frame), on: screen.frame)
        let source = ExposeLayout.local(ExposeLayout.sourceFrame(for: item, on: scene.activeFrame), on: screen.frame)
        let frame = scene.expanded || scene.reduceMotion ? target : source
        let selected = model.selectedID == item.id
        return Button {
            model.selectItem(item.id)
            onActivate(item.id)
        } label: {
            ZStack {
                if let image = model.images[item.id] {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    // Protected/minimized windows may have no capturable surface.
                    Color.black.opacity(0.3)
                    VStack(spacing: 8) {
                        appIcon(item.id.pid, size: min(36, target.height * 0.25))
                        Text(item.appName).font(.caption).lineLimit(1)
                        Text(localizedString("Preview unavailable")).font(.caption2).lineLimit(1)
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(width: max(1, frame.width), height: max(1, frame.height))
            .clipShape(RoundedRectangle(cornerRadius: scene.expanded ? 7 : 0))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(selected && decorationsVisible ? Color.accentColor : .clear, lineWidth: 3))
            .shadow(color: .black.opacity(scene.expanded ? 0.4 : 0), radius: scene.expanded ? 14 : 0, y: 5)
        }
        .buttonStyle(.plain)
        .position(x: frame.midX, y: frame.midY)
        .opacity(scene.reduceMotion || model.images[item.id] == nil ? (scene.expanded ? 1 : 0) : 1)
        .disabled(model.isBusy || scene.dismissing || !scene.expanded)
        .onHover { hovering in
            if hovering && decorationsVisible && scene.mode == .islands { model.selectItem(item.id) }
        }
        .accessibilityLabel(item.appName + ": " + item.displayTitle + ", " + model.exposeScreenLabel(for: item))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .help(item.displayTitle + " — " + model.exposeScreenLabel(for: item))
        .onAppear { model.requestPreview(item.id) }
        .onChange(of: model.generation) { _ in model.requestPreview(item.id) }
    }

    private func caption(_ placement: ExposeLayout.Placement) -> some View {
        let frame = ExposeLayout.local(scene.displayed(placement.caption), on: screen.frame)
        let title = scene.mode == .strip
            ? placement.item.displayTitle
            : placement.item.displayTitle + " · " + model.exposeScreenLabel(for: placement.item)
        return Text(title)
            .font(.system(size: min(12, frame.height * 0.75), weight: .medium))
            .foregroundStyle(.white.opacity(0.9)).lineLimit(1)
            .minimumScaleFactor(0.4)
            .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .opacity(decorationsVisible ? 1 : 0)
            .allowsHitTesting(false)
    }

    private func groupCard(_ heading: ExposeLayout.Heading) -> some View {
        let frame = ExposeLayout.local(scene.displayed(heading.bounds), on: screen.frame)
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.32))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 10, y: 3)
            .frame(width: max(1, frame.width + 16), height: max(1, frame.height + 12))
            .position(x: frame.midX, y: frame.midY)
            .opacity(decorationsVisible ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func appHeading(_ heading: ExposeLayout.Heading) -> some View {
        if scene.mode == .strip {
            stripBadge(heading)
        } else {
            islandTitle(heading)
        }
    }

    /// Strip: a compact app badge sits directly on the window card; the big
    /// floating title is gone (it read as unrelated to any window).
    private func stripBadge(_ heading: ExposeLayout.Heading) -> some View {
        let frame = ExposeLayout.local(scene.displayed(heading.bounds), on: screen.frame)
        return HStack(spacing: 6) {
            appIcon(heading.pid, size: 18)
            Text(heading.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            if heading.count > 1 {
                Text("×\(heading.count)").font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(.black.opacity(0.45), in: Capsule())
        .frame(maxWidth: frame.width, alignment: .leading)
        .position(x: frame.minX + 14, y: frame.minY + 14)
        .opacity(decorationsVisible ? 1 : 0)
        .allowsHitTesting(false)
    }

    private func islandTitle(_ heading: ExposeLayout.Heading) -> some View {
        let frame = ExposeLayout.local(scene.displayed(heading.frame), on: screen.frame)
        return HStack(spacing: min(8, frame.height * 0.25)) {
            appIcon(heading.pid, size: min(26, frame.height * 0.85))
            Text(heading.name).font(.system(size: min(22, frame.height * 0.7), weight: .semibold))
            Text("\(heading.count)").font(.system(size: min(16, frame.height * 0.55), weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
        .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.4)
        .shadow(color: .black.opacity(0.65), radius: 4, y: 1)
        .frame(width: frame.width, height: frame.height, alignment: .leading)
        .position(x: frame.midX, y: frame.midY)
        .opacity(decorationsVisible ? 1 : 0)
        .allowsHitTesting(false)
    }

    /// Only the actual top/bottom controls take hit regions. The desktop
    /// between them is reserved for window selection, not a full-frame HUD.
    private var floatingControls: some View {
        Group {
            headerControls
                .frame(width: screen.frame.width - 48)
                .position(x: screen.frame.width / 2,
                          y: screen.safeTop + (screen.frame.width < 900 ? 48 : 26))
            if !model.accessibilityGranted || !model.previewsGranted || !model.message.isEmpty {
                notice.frame(maxWidth: screen.frame.width - 48)
                    .position(x: screen.frame.width / 2,
                              y: screen.safeTop + (screen.frame.width < 900 ? 134 : 88))
            }
            ViewThatFits(in: .horizontal) {
                HStack { keyboardHint; Spacer(minLength: 12); actions }
                VStack(spacing: 10) { actions; keyboardHint }
            }
            .frame(width: screen.frame.width - 48)
            .position(x: screen.frame.width / 2, y: screen.frame.height - (screen.frame.width < 1100 ? 44 : 28))
        }
        .foregroundStyle(.white)
        .opacity(decorationsVisible ? 1 : 0)
        .allowsHitTesting(decorationsVisible)
    }

    private var headerControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Exposé PK").font(.system(size: 18, weight: .semibold))
                    Text(String(format: localizedString("%d windows"), model.items.count))
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 8)
                modePicker
                if screen.frame.width >= 900 { searchField }
                Button(action: onClose) { Image(systemName: "xmark").padding(10) }
                    .buttonStyle(.plain).background(.ultraThinMaterial, in: Circle())
                    .accessibilityLabel(localizedString("Dismiss picker"))
            }
            if screen.frame.width < 900 { searchField }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField(localizedString("Search windows or apps"), text: $model.query)
                .textFieldStyle(.plain).focused($searchFocused)
                .accessibilityLabel(localizedString("Search windows or apps"))
            if !model.query.isEmpty {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).accessibilityLabel(localizedString("Clear search"))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(width: screen.frame.width < 900 ? screen.frame.width - 80 : min(300, screen.frame.width * 0.25))
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var modePicker: some View {
        HStack(spacing: 3) {
            ForEach(ExposeLayout.Mode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(scene.reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        scene.setMode(mode)
                        scene.reveal(model.selectedID)
                    }
                } label: {
                    Label(localizedString(mode == .islands ? "Islands" : "Android strip"),
                          systemImage: mode == .islands ? "square.grid.3x2" : "rectangle.split.3x1")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 11).padding(.vertical, 8)
                        .background(scene.mode == mode ? Color.white.opacity(0.22) : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(scene.mode == mode ? [.isSelected] : [])
            }
        }
        .padding(3).background(.ultraThinMaterial, in: Capsule())
        .disabled(scene.dismissing || model.isBusy)
    }

    private var keyboardHint: some View {
        Text(localizedString(scene.mode == .strip
            ? "Scroll horizontally · ← → Windows · ↑ ↓ Apps · ↵ Open · esc Dismiss"
            : "← → Windows · ↑ ↓ Apps · ↵ Open · esc Return to desktop"))
            .font(.caption).foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button { if let id = model.selectedID { model.closeWindow(id) } } label: {
                Text(localizedString("Close window") + "  ⌘W")
            }.disabled(!canAct)
            Button { if let id = model.selectedID { model.quitApp(id) } } label: {
                Text(localizedString("Quit app") + "  ⌘Q")
            }.disabled(!canAct)
            Button { model.prepare(resetSearch: false) } label: { Image(systemName: "arrow.clockwise") }
                .accessibilityLabel(localizedString("Refresh")).disabled(model.isBusy)
            Text("v" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"))
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
        }
        .buttonStyle(.bordered).fixedSize()
    }

    private var notice: some View {
        HStack(spacing: 12) {
            if !model.accessibilityGranted {
                Text(localizedString("Accessibility is required to list and select windows."))
                Button(localizedString("Grant Accessibility…")) { model.requestAccessibility() }
            } else if !model.previewsGranted {
                Text(localizedString("Enable Screen Recording for window thumbnails. Titles remain available."))
                Button(localizedString("Enable previews…")) { model.requestPreviews() }
            } else {
                Text(model.message).lineLimit(2)
            }
        }
        .font(.callout).padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func appIcon(_ pid: Int32, size: CGFloat) -> some View {
        if let icon = model.icons[pid] {
            Image(nsImage: icon).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Image(systemName: "app").resizable().scaledToFit().frame(width: size, height: size)
        }
    }

    private func updateLayout() {
        guard primary, !scene.dismissing else { return }
        withAnimation(scene.reduceMotion || !scene.expanded ? nil : .easeInOut(duration: 0.2)) {
            scene.update(groups: model.exposeGroups, hasNotice: !model.accessibilityGranted || !model.previewsGranted || !model.message.isEmpty)
        }
    }
}
