import SwiftUI

struct WindowSwitcherView: View {
    @ObservedObject var model: WindowSwitcherModel
    @ObservedObject var roomStore: RoomStore
    let onActivate: (WindowSwitcherID) -> Void
    let onClose: () -> Void
    @FocusState private var searchFocused: Bool
    @FocusState private var roomNameFocused: Bool
    @FocusState private var roomRenameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)
            if model.isCreatingRoom {
                roomCreationBar
                Divider().opacity(0.55)
            }
            if !model.accessibilityGranted {
                permissionView
            } else {
                if !model.isCreatingRoom { roomsStrip }
                if !model.previewsGranted { previewPermissionBanner }
                if let name = model.quittingName { quittingBanner(name) }
                if !model.message.isEmpty {
                    messageBanner
                }
                if model.isLoading {
                    ProgressView(localizedString("Loading windows…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.filteredItems.isEmpty {
                    emptyView
                } else {
                    windowGrid
                }
            }
            Divider().opacity(0.55)
            footer
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear { searchFocused = true }
        .onChange(of: model.query) { _ in model.loadLauncherAppsIfNeeded() }
        .overlay {
            if model.roomActionTargetID != nil || model.renamingRoomID != nil {
                roomActionsOverlay
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                title
                Spacer(minLength: 12)
                searchField.frame(maxWidth: 400)
                headerButtons
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    title
                    Spacer(minLength: 12)
                    headerButtons
                }
                searchField
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var title: some View {
        HStack(spacing: 9) {
            Label(localizedString("Window previews"), systemImage: "rectangle.on.rectangle")
                .font(.headline)
            if !model.isLoading, model.accessibilityGranted {
                Text("\(model.filteredItems.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.primary.opacity(0.06), in: Capsule())
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(localizedString("Search by app or window title"), text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
                .accessibilityLabel(localizedString("Search by app or window title"))
            if !model.query.isEmpty {
                Button { model.query = ""; searchFocused = true } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(localizedString("Clear"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private var headerButtons: some View {
        HStack(spacing: 6) {
            if !model.isCreatingRoom {
                Button { model.beginRoomCreation() } label: {
                    Label(localizedString("New Room"), systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary.opacity(0.75))
                .help(localizedString("New Room"))
                .accessibilityLabel(localizedString("New Room"))
            }
            Button { model.prepare(resetSearch: false) } label: { Image(systemName: "arrow.clockwise") }
                .help(localizedString("Refresh") + " (⌘R)")
                .accessibilityLabel(localizedString("Refresh"))
            Button(action: onClose) { Image(systemName: "xmark") }
                .help(localizedString("Dismiss picker"))
                .accessibilityLabel(localizedString("Dismiss picker"))
        }
        .buttonStyle(.plain)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(height: 26)
    }

    private var messageBanner: some View {
        let tone = model.messageKind
        return HStack(spacing: 8) {
            Image(systemName: tone == .success ? "checkmark.circle.fill"
                    : (tone == .error ? "exclamationmark.triangle.fill" : "info.circle.fill"))
                .foregroundStyle(tone == .success ? Color.green
                        : (tone == .error ? Color.orange : Color.secondary))
            Text(model.message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tone == .success ? Color.green.opacity(0.15)
                : (tone == .error ? Color.orange.opacity(0.15) : Color.gray.opacity(0.12)),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var roomMatches: [Room] {
        model.rooms(matching: model.query)
    }

    private var roomActionsOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
            if model.renamingRoomID != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Label(localizedString("Rename"), systemImage: "pencil")
                        .font(.headline)
                    TextField(localizedString("Room name"), text: $model.renameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.primary.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .focused($roomRenameFieldFocused)
                        .onSubmit { model.commitRename() }
                    HStack {
                        Spacer(minLength: 0)
                        Button(localizedString("Cancel")) { model.renamingRoomID = nil }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        Button {
                            model.commitRename()
                        } label: {
                            Label(localizedString("Save"), systemImage: "checkmark")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.9), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(width: 320)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1))
                .onAppear { roomRenameFieldFocused = true }
            } else if let room = model.roomActionTarget {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(room.name)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(room.windows.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(RoomAction.allCases.enumerated()), id: \.element) { index, action in
                        Button {
                            model.performRoomAction(action, for: room)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: action.symbolName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 18)
                                Text(action.title)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(index == model.roomActionSelection
                                    ? Color.accentColor.opacity(0.16)
                                    : Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                    }
                    HStack(spacing: 10) {
                        Text("↑ ↓  ·  ↵")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text("⌘K")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
                .padding(14)
                .frame(width: 300)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1))
            }
        }
    }

    private var roomsStrip: some View {
        let rows = roomMatches
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(localizedString("Rooms"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text("\(rows.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.primary.opacity(0.06), in: Capsule())
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(rows) { room in
                                RoomPickerCard(room: room, model: model, onClose: onClose)
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 2)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Room creation

    private var roomCreationBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(localizedString("Room name"), text: $model.roomName)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: 260)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .focused($roomNameFocused)
                .onSubmit { if model.canCreateRoom { model.createRoom() } }
            Text(String(format: localizedString("%d window(s) selected"), model.roomPicks.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            Menu {
                ForEach(RoomLayoutKind.allCases) { kind in
                    Button(kind.title) { model.creationLayout = kind }
                }
            } label: {
                Label(model.creationLayout.title, systemImage: "rectangle.grid.2x2")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.primary.opacity(0.05), in: Capsule())
            }
            .fixedSize()
            Spacer(minLength: 8)
            Button(localizedString("Cancel")) { model.cancelRoomCreation() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Button { model.createRoom() } label: {
                Label(localizedString("Create Room"), systemImage: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(model.canCreateRoom ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.06),
                                in: Capsule())
                    .foregroundStyle(model.canCreateRoom ? Color.white : Color(nsColor: .secondaryLabelColor))
            }
            .buttonStyle(.plain)
            .disabled(!model.canCreateRoom)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(.primary.opacity(0.03))
        .onAppear { roomNameFocused = true }
    }

    // MARK: - Content

    private var windowGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: WindowSwitcherState.gridSpacing),
                                        count: model.columns),
                          spacing: WindowSwitcherState.gridSpacing) {
                    ForEach(Array(model.filteredItems.enumerated()), id: \.element.id) { rank, item in
                        let pickIndex = model.roomPickIndex(for: item.id)
                        WindowSwitcherCard(item: item, icon: model.icons[item.id.pid], image: model.images[item.id],
                            isSelected: model.selectedID == item.id, rank: rank, cardHeight: model.cardHeight,
                            isRoomPicking: model.isCreatingRoom, pickIndex: pickIndex,
                            isLoadingPreview: model.previewsGranted && !model.completedPreviews.contains(item.id),
                            isClosing: model.closingID == item.id, isQuitting: model.quittingPID == item.id.pid,
                            closeInProgress: model.isBusy,
                            onActivate: {
                                if model.isCreatingRoom {
                                    model.selectedID = item.id
                                    model.toggleRoomPick(item.id)
                                } else {
                                    onActivate(item.id)
                                }
                            }, onCloseWindow: { model.closeWindow(item.id) },
                            onQuitApp: { model.quitApp(item.id) })
                            .frame(height: model.cardHeight)
                            .id(item.id)
                            .onAppear { model.requestPreview(item.id) }
                    }
                }
                .padding(WindowSwitcherState.gridPadding)
            }
            .id(model.generation)
            .onChange(of: model.selectedID) { id in
                if let id { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "macwindow").font(.system(size: 34, weight: .light)).foregroundStyle(.secondary)
                Text(localizedString(model.query.isEmpty ? "No windows available" : "No matching windows"))
                if !model.query.isEmpty {
                    let rows = model.fallbackActions(query: model.query).enumerated().map {
                        FallbackRow(id: $0.offset, action: $0.element)
                    }
                    if model.isLoadingLauncherApps && model.launcherMatches.isEmpty && rows.count <= 1 {
                        ProgressView().controlSize(.small)
                    } else {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(rows) { row in
                                fallbackRow(index: row.id, action: row.action)
                            }
                        }
                        .frame(maxWidth: 380)
                    }
                    Text("↑ ↓  ·  ↵")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Button(localizedString("Refresh")) { model.prepare(resetSearch: false) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 280)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func fallbackRow(index: Int, action: WindowSwitcherModel.FallbackAction) -> some View {
        let isSelected = index == model.fallbackSelection
        Button {
            switch action {
            case .room(let room):
                model.activateRoom(room)
                onClose()
            case .app(let app):
                model.launch(app)
                onClose()
            case .createRoom(let name):
                model.beginRoomCreation(named: name)
            }
        } label: {
            HStack(spacing: 10) {
                switch action {
                case .room(let room):
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(room.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Text(room.layout.title).font(.caption2).foregroundStyle(.secondary)
                    }
                case .app(let app):
                    Image(nsImage: app.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                case .createRoom(let name):
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    Text(String(format: localizedString("Create room with name “%@”"), name))
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                switch action {
                case .room: Text(localizedString("Open Room")).font(.caption).foregroundStyle(.secondary)
                case .app: Text(localizedString("Open")).font(.caption).foregroundStyle(.secondary)
                case .createRoom: Text(localizedString("New Room")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 380)
    }

    private func quittingBanner(_ name: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(String(format: localizedString("Quitting %@…"), name))
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(.primary.opacity(0.035))
    }

    private var previewPermissionBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "photo").foregroundStyle(.secondary)
            Text(localizedString("Enable Screen Recording to show thumbnails. Reopen the picker after granting access; macOS may ask you to restart the app."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(localizedString("Enable previews…")) { model.requestPreviews() }
        }
        .padding(14).background(.primary.opacity(0.035))
    }

    private var permissionView: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.raised").font(.system(size: 34)).foregroundStyle(.secondary)
            Text(localizedString("Allow Accessibility to list and activate your windows."))
                .multilineTextAlignment(.center)
            Button(localizedString("Open Accessibility Settings")) { model.requestAccessibility() }
            Button(localizedString("Refresh")) { model.prepare(resetSearch: false) }
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        Group {
            if model.isCreatingRoom {
                HStack(spacing: 14) {
                    Text(localizedString("Click windows in order — 1 is the main spot"))
                        .font(.caption2)
                    Spacer(minLength: 0)
                    hint("⌥Space", "Add")
                    hint("↵", "Create Room")
                    hint("esc", "Cancel")
                }
            } else {
                HStack(spacing: 14) {
                    hint("⇥", "Browse")
                    hint("↵", "Open")
                    hint("⌘W", "Close")
                    hint("⌘Q", "Quit app")
                    if model.columns >= 3 {
                        hint("⌘1–9", "Quick select")
                        hint("⌘N", "New Room")
                    }
                    if !model.roomStore.rooms.isEmpty {
                        hint("⌘K", "Room actions")
                        hint("⌥⇥", "Switch room")
                    }
                    Spacer(minLength: 0)
                    hint("esc", "Dismiss picker")
                }
            }
        }
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.horizontal, 18).padding(.vertical, 10)
    }

    private func hint(_ key: String, _ title: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.8))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(localizedString(title))
        }
    }
}

struct WindowSwitcherCard: View {
    let item: WindowSwitcherItem
    let icon: NSImage?
    let image: NSImage?
    let isSelected: Bool
    let rank: Int
    let cardHeight: CGFloat
    let isRoomPicking: Bool
    let pickIndex: Int?
    var isLoadingPreview = false
    var isClosing = false
    var isQuitting = false
    var closeInProgress = false
    let onActivate: () -> Void
    let onCloseWindow: () -> Void
    let onQuitApp: () -> Void
    @State private var isHovering = false

    var body: some View {
        GeometryReader { geometry in
            let insets = imageInsets(for: geometry.size.width)
            ZStack(alignment: .topTrailing) {
                Button(action: onActivate) {
                    cardSurface(insets: insets)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .buttonStyle(.plain)
                .disabled(closeInProgress)
                .help(item.appName + " — " + item.displayTitle)
                .accessibilityLabel(item.appName + ", " + item.displayTitle)
                .accessibilityValue(isSelected ? localizedString("Selected") : "")
                .accessibilityHint(localizedString("Activate this window"))
                if !isRoomPicking {
                    closeButton
                        .padding(.top, insets.height + 9)
                        .padding(.trailing, insets.width + 9)
                }
            }
            .onHover { hovering in isHovering = hovering }
            .contextMenu {
                if !isRoomPicking {
                    Button(localizedString("Close window")) { onCloseWindow() }
                        .disabled(closeInProgress)
                    Button(String(format: localizedString("Quit %@"), item.appName)) { onQuitApp() }
                        .disabled(closeInProgress)
                }
            }
        }
    }

    private func cardSurface(insets: CGSize) -> some View {
        VStack(spacing: 0) {
            imageArea(insets: insets)
                .frame(height: imageHeight)
            captionBar(insets: insets)
                .frame(height: WindowSwitcherState.cardCaptionHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var imageHeight: CGFloat {
        max(120, cardHeight - WindowSwitcherState.cardCaptionHeight)
    }

    /// Insets of the fitted image inside its area. The close button and the
    /// badges follow the thumbnail, never the wider card frame.
    private func imageInsets(for width: CGFloat) -> CGSize {
        guard let image, image.size.width > 0, image.size.height > 0 else { return .zero }
        let area = CGSize(width: max(1, width), height: imageHeight)
        let scale = min(area.width / image.size.width, area.height / image.size.height)
        return CGSize(width: max(0, (area.width - image.size.width * scale) / 2),
                      height: max(0, (area.height - image.size.height * scale) / 2))
    }

    // MARK: - Image

    private func imageArea(insets: CGSize) -> some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(imageBorder)
                    .shadow(color: .black.opacity(0.10), radius: 4, y: 0)
                    .shadow(color: isSelected || pickIndex != nil ? Color.accentColor.opacity(0.18) : .clear,
                            radius: 6)
            } else {
                fallbackThumbnail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(imageBorder)
            }
            if isQuitting {
                Color.black.opacity(0.32)
                ProgressView().controlSize(.small).tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                if isRoomPicking { roomPickBadge } else { rankBadge }
                if let status { statusBadge(status) }
            }
            .padding(.leading, insets.width + 9)
            .padding(.top, insets.height + 9)
        }
        .frame(maxWidth: .infinity)
    }

    private var fallbackThumbnail: some View {
        VStack(spacing: 8) {
            appIcon.frame(width: 48, height: 48)
            if isLoadingPreview {
                ProgressView().controlSize(.small)
            } else {
                Text(localizedString("Preview unavailable"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var rankBadge: some View {
        if rank < 9 {
            Text("⌘\(rank + 1)")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.black.opacity(0.56), in: Capsule())
        }
    }

    private var roomPickBadge: some View {
        ZStack {
            Circle().fill(pickIndex == nil ? Color.black.opacity(0.36) : Color.accentColor)
            if let pickIndex {
                Text("\(pickIndex)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: 24, height: 24)
        .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1))
    }

    private func statusBadge(_ key: String) -> some View {
        Label(localizedString(key), systemImage: statusIcon)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.black.opacity(0.56), in: Capsule())
    }

    private func captionBar(insets: CGSize) -> some View {
        HStack(spacing: 8) {
            appIcon.frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 0) {
                if item.title.isEmpty {
                    Text(item.appName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                } else {
                    Text(item.appName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.leading, insets.width + 2)
        .padding(.trailing, 2)
    }

    private var imageBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(isSelected || pickIndex != nil
                            ? Color.accentColor
                            : Color.primary.opacity(isHovering ? 0.16 : 0),
                          lineWidth: isSelected || pickIndex != nil ? 2.5 : 1)
    }

    private var closeButton: some View {
        Button(action: onCloseWindow) { closeGlyph }
            .buttonStyle(.plain)
            .disabled(closeInProgress)
            .opacity(isHovering || isSelected || isClosing ? 1 : 0.62)
            .help(localizedString("Close window") + " — " + item.displayTitle + " (⌘W)")
            .accessibilityLabel(closeAccessibilityLabel)
    }

    private var closeAccessibilityLabel: String {
        localizedString(isClosing ? "Closing window…" : "Close window") + ", " + item.appName + ", " + item.displayTitle
    }

    private var closeGlyph: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.46))
            if isClosing {
                ProgressView().controlSize(.small).tint(.white)
            } else {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
            }
        }
        .frame(width: 26, height: 26)
        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
    }

    @ViewBuilder private var appIcon: some View {
        if let icon { Image(nsImage: icon).resizable().scaledToFit() }
        else { Image(systemName: "macwindow").resizable().scaledToFit().foregroundStyle(.secondary) }
    }

    private var status: String? {
        if item.isMinimized { return "Minimized" }
        if item.isHidden { return "Hidden app" }
        if item.isFullScreen { return "Fullscreen" }
        if !item.isOnScreen { return "Off screen" }
        return nil
    }

    private var statusIcon: String {
        if item.isMinimized { return "rectangle.compress.vertical" }
        if item.isHidden { return "eye.slash" }
        if item.isFullScreen { return "arrow.up.left.and.arrow.down.right" }
        return "rectangle.dashed"
    }
}

private struct RoomPickerCard: View {
    let room: Room
    @ObservedObject var model: WindowSwitcherModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Text(room.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                layoutMenu
            }
            Text(windowSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 8) {
                Button {
                    model.activateRoom(room)
                    onClose()
                } label: {
                    Label(localizedString("Open Room"), systemImage: "arrow.up.forward")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.9), in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Button {
                    model.minimizeRoom(room)
                } label: {
                    Label(localizedString("Minimize Room"), systemImage: "arrow.down.to.line")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.primary.opacity(0.06), in: Capsule())
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text("\(room.windows.count)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 250, alignment: .leading)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.primary.opacity(0.08), lineWidth: 1))
        .contextMenu {
            Button(localizedString("Delete Room")) { model.roomStore.delete(id: room.id) }
        }
    }

    private var windowSummary: String {
        let names = room.windows.map(\.appName)
        guard !names.isEmpty else { return localizedString("No windows available") }
        let head = names.prefix(3).joined(separator: " · ")
        return names.count > 3 ? head + " …" : head
    }

    private var layoutMenu: some View {
        Menu {
            ForEach(RoomLayoutKind.allCases) { kind in
                Button(kind.title) { model.setRoomLayout(kind, for: room) }
            }
        } label: {
            Label(room.layout.title, systemImage: layoutSymbol(room.layout))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.primary.opacity(0.06), in: Capsule())
        }
        .fixedSize()
    }

    private func layoutSymbol(_ kind: RoomLayoutKind) -> String {
        switch kind {
        case .auto: return "rectangle.split.2x2"
        case .focus: return "target"
        case .columns: return "rectangle.split.3x1"
        case .grid: return "square.grid.3x3"
        case .stack: return "rectangle.stack"
        case .dwindle: return "rectangle.split.2x2"
        case .monocle: return "rectangle.on.rectangle"
        }
    }
}

private struct FallbackRow: Identifiable {
    let id: Int
    let action: WindowSwitcherModel.FallbackAction
}
