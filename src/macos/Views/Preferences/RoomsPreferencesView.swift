import AppKit
import SwiftUI

/// Visual Studio for Rooms: saved window-position scenes & dynamic project layouts.
struct RoomsPreferencesView: View {
    @ObservedObject private var store: RoomStore
    @ObservedObject private var canvas = HorizontalCanvasService.shared
    @StateObject private var model: RoomsSwitcherModel
    @State private var query = ""
    @State private var editingRoom: Room?
    @State private var deletedRoom: Room?
    @State private var statusBanner: String?

    init(store: RoomStore = .shared) {
        self.store = store
        _model = StateObject(wrappedValue: RoomsSwitcherModel(store: store))
    }

    private var visibleRooms: [Room] { store.rooms.filter { $0.matches(query) } }
    private var accent: Color { PKStudioPalette.roomsAccent }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PKStudioSectionHeader(
                    title: "Rooms & Saved Window Scenes",
                    subtitle: "Switch from one Room to another with recorded window positions, or jump into Tiling / Strip (OpenCanvas) and back to Free mode.",
                    systemImage: "rectangle.3.group.fill",
                    tint: accent
                ) {
                    HStack(spacing: 8) {
                        Button {
                            captureCurrentScreenIntoNewRoom()
                        } label: {
                            Label(localizedString("Capture current screen"), systemImage: "camera.viewfinder")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            editingRoom = Room(name: "", windows: [])
                        } label: {
                            Label(localizedString("New Room"), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                    }
                }

                // Live mode switcher bar (Free / Tiling / Strip + Open Rooms ⌃⌥R)
                PKStudioCard(tint: accent, padding: 12) {
                    HStack(spacing: 12) {
                        PKOverlayModeSwitcherBar()
                        Divider().frame(height: 20)
                        Button {
                            RoomsOverlayController.shared.show()
                        } label: {
                            HStack(spacing: 5) {
                                Text(localizedString("Open Rooms"))
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                Text("⌃⌥R")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if let statusBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(statusBanner)
                            .font(.caption.weight(.medium))
                        Spacer()
                        Button {
                            self.statusBanner = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let deletedRoom {
                    HStack {
                        Text(String(format: localizedString("Room removed: %@"), deletedRoom.name))
                            .font(.callout.weight(.medium))
                        Spacer()
                        Button(localizedString("Undo")) {
                            store.upsert(deletedRoom)
                            self.deletedRoom = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if !store.rooms.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(localizedString("Search rooms…"), text: $query)
                            .textFieldStyle(.plain)
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Text(String(format: localizedString("%d room(s)"), visibleRooms.count))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if visibleRooms.isEmpty {
                    emptyRoomsStudioCard
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 420), spacing: 14)], spacing: 14) {
                        ForEach(visibleRooms) { room in
                            roomCard(room)
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            model.prepare()
            canvas.refreshCurrentWorkspace()
        }
        .sheet(item: $editingRoom) { room in
            RoomEditorView(room: room, store: store)
        }
    }

    private var emptyRoomsStudioCard: some View {
        PKStudioCard(tint: accent, padding: 24) {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.14))
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 6) {
                    Text(localizedString(store.rooms.isEmpty ? "No rooms yet. Create your first room from your open windows." : "No matching rooms."))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    if store.rooms.isEmpty {
                        Text(localizedString("Arrange your windows on screen and click “Capture current screen” to save their exact positions, or pick a dynamic layout."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Button {
                                captureCurrentScreenIntoNewRoom()
                            } label: {
                                Label(localizedString("Capture current screen"), systemImage: "camera.viewfinder")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)

                            Button(localizedString("New Room")) {
                                editingRoom = Room(name: "", windows: [])
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    }
                }
                Spacer()
            }
        }
    }

    private func roomCard(_ room: Room) -> some View {
        let isActiveRoom = canvas.displayWorkspaces.contains { $0.profile.activeRoomID == room.id }
        let usesSaved = room.useSavedFrames && room.hasSavedFrames

        return PKStudioCard(tint: accent, isHighlighted: isActiveRoom, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(room.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            if isActiveRoom {
                                Text(localizedString("Active"))
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(accent.opacity(0.20), in: Capsule())
                                    .foregroundStyle(accent)
                            }
                        }

                        // Metadata pills
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: usesSaved ? "mappin.and.ellipse" : "square.grid.2x2")
                                    .font(.system(size: 9.5, weight: .semibold))
                                Text(room.placementModeSummary)
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(usesSaved ? accent.opacity(0.16) : PKStudioPalette.tilingAccent.opacity(0.14))
                            )
                            .foregroundStyle(usesSaved ? accent : PKStudioPalette.tilingAccent)

                            HStack(spacing: 4) {
                                Image(systemName: "display")
                                    .font(.system(size: 9.5, weight: .semibold))
                                Text(model.screenName(for: room) ?? localizedString("Screen under pointer"))
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                            .foregroundStyle(.secondary)

                            Text(room.handoffPolicy.shortTitle)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.05), in: Capsule())
                                .foregroundStyle(.secondary)
                        }

                        // App icon strip + window titles
                        HStack(spacing: 6) {
                            ForEach(Array(room.windows.prefix(6).enumerated()), id: \.element.id) { _, win in
                                Image(nsImage: RoomIconCache.icon(for: win))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .help(win.title.isEmpty ? win.appName : "\(win.appName) — \(win.title)")
                            }
                            Text(room.windows.map { $0.title.isEmpty ? $0.appName : $0.title }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)

                    RoomLayoutDiagram(room: room)
                        .frame(width: 168)
                        .accessibilityLabel(room.placementModeSummary)
                }

                Divider()

                HStack(spacing: 8) {
                    Button {
                        model.activate(room: room)
                    } label: {
                        Label(localizedString("Open Room"), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.small)

                    Button {
                        let claimed = store.claimedWindowIDs(excluding: room.id)
                        let updated = RoomEngine().capturePositions(for: room, claimed: claimed)
                        store.upsert(updated)
                        statusBanner = String(format: localizedString("Saved current window positions for “%@”."), room.name)
                    } label: {
                        Label(localizedString("Save positions"), systemImage: "mappin.and.ellipse")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(localizedString("Record the current on-screen position and size of this Room's windows"))

                    Button {
                        var stripRoom = room
                        stripRoom.handoffPolicy = .adoptWorkspaceMode
                        canvas.setWorkspaceMode(.strip, onDisplayUUID: room.displayUUID)
                        model.activate(room: stripRoom)
                    } label: {
                        Label("Strip", systemImage: "rectangle.3.group.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(localizedString("Open this Room and switch its screen to Strip (OpenCanvas) mode"))

                    Button(localizedString("Edit Room")) {
                        editingRoom = room
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(localizedString("Minimize Room")) {
                        model.minimize(room: room)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button {
                        editingRoom = Room(
                            name: String(format: localizedString("%@ — copy"), room.name),
                            windows: room.windows.map {
                                RoomWindow(bundleID: $0.bundleID, appName: $0.appName,
                                           title: $0.title, windowID: $0.windowID,
                                           savedFrame: $0.savedFrame)
                            },
                            layout: room.layout,
                            displayUUID: room.displayUUID,
                            useSavedFrames: room.useSavedFrames,
                            handoffPolicy: room.handoffPolicy
                        )
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .buttonStyle(.borderless)
                    .help(localizedString("Duplicate Room"))
                    .accessibilityLabel(localizedString("Duplicate Room"))

                    Button {
                        deletedRoom = room
                        store.delete(id: room.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.borderless)
                    .help(localizedString("Delete Room"))
                    .accessibilityLabel(localizedString("Delete Room"))
                }
            }
        }
    }

    private func captureCurrentScreenIntoNewRoom() {
        let captured = RoomEngine().captureScreenWindows(displayUUID: canvas.currentWorkspace?.key.displayUUID)
        let defaultName = String(format: localizedString("Scene %d"), store.rooms.count + 1)
        editingRoom = Room(
            name: defaultName,
            windows: captured.windows,
            layout: .auto,
            displayUUID: captured.displayUUID,
            useSavedFrames: true,
            handoffPolicy: .keepRoomPositions
        )
    }
}

/// Visual Room Editor: supports both recorded window positions (`useSavedFrames`)
/// and dynamic layouts (`RoomLayoutKind`), plus handoff policy (`Keep` vs `Adopt`).
struct RoomEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: RoomStore
    @State private var draft: Room
    @State private var offers: [RoomEngine.WindowOffer] = []
    @State private var screens: [RoomEngine.ScreenOption] = []
    @State private var loading = false
    @State private var permissionMissing = false
    @FocusState private var nameFocused: Bool
    private let isNew: Bool
    private let loadsWindowOffers: Bool

    init(room: Room, store: RoomStore, loadsWindowOffers: Bool = true) {
        self.store = store
        _draft = State(initialValue: room)
        isNew = !store.rooms.contains { $0.id == room.id }
        self.loadsWindowOffers = loadsWindowOffers
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draft.windows.isEmpty
    }

    private var accent: Color { PKStudioPalette.roomsAccent }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top stage: Live Room preview + Name & Target Screen
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localizedString(isNew ? "New Room" : "Edit Room"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    TextField(localizedString("Room name"), text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)

                    HStack(spacing: 10) {
                        Picker(localizedString("Screen"), selection: $draft.displayUUID) {
                            Text(localizedString("Screen under pointer")).tag(String?.none)
                            ForEach(screens) { screen in Text(screen.name).tag(Optional(screen.uuid)) }
                            if let uuid = draft.displayUUID, !screens.contains(where: { $0.uuid == uuid }) {
                                Text(localizedString("Disconnected screen")).tag(Optional(uuid))
                            }
                        }
                        .frame(maxWidth: 240)

                        Button {
                            let captured = RoomEngine().capturePositions(for: draft)
                            draft = captured
                        } label: {
                            Label(localizedString("Capture current screen positions"), systemImage: "camera.viewfinder")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    RoomLayoutDiagram(room: draft)
                        .frame(width: 175)
                    Text(draft.placementModeSummary)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }
            }

            // Placement Mode & Handoff Policy Visual Selector
            HStack(spacing: 10) {
                placementModeButton(
                    title: localizedString("Saved Window Positions"),
                    subtitle: localizedString("Restores exact recorded x/y/size on screen"),
                    icon: "mappin.and.ellipse",
                    isSelected: draft.useSavedFrames
                ) {
                    if !draft.hasSavedFrames {
                        draft = RoomEngine().capturePositions(for: draft)
                    } else {
                        draft.useSavedFrames = true
                    }
                    draft.handoffPolicy = .keepRoomPositions
                }

                placementModeButton(
                    title: localizedString("Dynamic Layout"),
                    subtitle: localizedString("Arranges windows with one of the 7 rules below"),
                    icon: "square.grid.2x2",
                    isSelected: !draft.useSavedFrames
                ) {
                    draft.useSavedFrames = false
                }

                Picker("", selection: $draft.handoffPolicy) {
                    ForEach(RoomHandoffPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }

            if !draft.useSavedFrames {
                layoutChoices
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(String(format: localizedString("%d window(s) selected"), draft.windows.count))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Text(localizedString("Click windows in order — 1 is the main spot"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(draft.windows.enumerated()), id: \.element.id) { index, window in
                        selectedWindow(window, index: index)
                    }

                    Divider().padding(.vertical, 4)

                    HStack {
                        Text(localizedString("Available windows"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        if loading { ProgressView().controlSize(.small) }
                        Button(localizedString("Refresh")) { refresh() }.disabled(loading)
                            .controlSize(.small)
                    }

                    if permissionMissing {
                        Text(localizedString("Allow Accessibility access to select and arrange your windows."))
                            .font(.callout).foregroundStyle(.secondary)
                        Button(localizedString("Grant Accessibility Access")) {
                            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                            _ = AXIsProcessTrustedWithOptions(options)
                        }
                    } else if offers.isEmpty && !loading {
                        Text(localizedString("No compatible windows found. Open your project apps, then refresh."))
                            .font(.callout).foregroundStyle(.secondary)
                    }

                    ForEach(offers) { offer in
                        HStack {
                            windowLabel(name: offer.appName, title: offer.title, bundleID: offer.bundleID,
                                        hasSavedFrame: offer.normalizedFrame != nil)
                            Spacer()
                            Button(localizedString(contains(offer) ? "Selected" : "Add")) {
                                draft.windows.append(
                                    RoomWindow(
                                        bundleID: offer.bundleID,
                                        appName: offer.appName,
                                        title: offer.title,
                                        windowID: offer.windowID,
                                        savedFrame: offer.normalizedFrame
                                    )
                                )
                            }
                            .disabled(contains(offer))
                            .controlSize(.small)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Divider()

            HStack {
                RoomLayoutDiagram(room: draft)
                    .frame(width: 108)
                Spacer()
                Button(localizedString("Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(localizedString("Save Room")) {
                    draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.upsert(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(22)
        .frame(width: 720, height: 640)
        .onAppear {
            refresh()
            DispatchQueue.main.async { nameFocused = true }
        }
    }

    private func placementModeButton(title: String, subtitle: String, icon: String,
                                     isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : .secondary)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? accent.opacity(0.75) : Color.primary.opacity(0.08),
                                  lineWidth: isSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var layoutChoices: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(RoomLayoutKind.allCases) { kind in
                    Button {
                        draft.layout = kind
                        draft.useSavedFrames = false
                    } label: {
                        VStack(spacing: 5) {
                            RoomLayoutDiagram(windows: draft.windows, kind: kind, useSavedFrames: false)
                            Text(kind.title)
                                .font(.system(size: 10, weight: draft.layout == kind ? .bold : .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(
                            draft.layout == kind ? accent.opacity(0.14) : Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(draft.layout == kind ? accent : Color.primary.opacity(0.08),
                                        lineWidth: draft.layout == kind ? 1.6 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(kind.title)
                    .accessibilityAddTraits(draft.layout == kind ? [.isSelected] : [])
                }
            }
        }
    }

    private func selectedWindow(_ window: RoomWindow, index: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .frame(width: 22, height: 22)
                .background(accent.opacity(0.15), in: Circle())
                .foregroundStyle(accent)

            windowLabel(name: window.appName, title: window.title, bundleID: window.bundleID,
                        hasSavedFrame: window.savedFrame != nil)
            Spacer()
            Button { draft.windows.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }
                .disabled(index == 0).accessibilityLabel(localizedString("Move up"))
            Button { draft.windows.swapAt(index, index + 1) } label: { Image(systemName: "arrow.down") }
                .disabled(index == draft.windows.count - 1).accessibilityLabel(localizedString("Move down"))
            Button { draft.windows.remove(at: index) } label: { Image(systemName: "minus.circle") }
                .accessibilityLabel(localizedString("Remove window"))
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func windowLabel(name: String, title: String, bundleID: String, hasSavedFrame: Bool) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: RoomIconCache.icon(bundleID: bundleID, name: name))
                .resizable()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title.isEmpty ? name : title)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)
                    if hasSavedFrame {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(accent)
                            .help(localizedString("Position recorded"))
                    }
                }
                if !title.isEmpty {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func contains(_ offer: RoomEngine.WindowOffer) -> Bool {
        draft.windows.contains { slot in
            guard slot.bundleID == offer.bundleID else { return false }
            if let id = slot.windowID, let offeredID = offer.windowID { return id == offeredID }
            return slot.title == offer.title
        }
    }

    private func refresh() {
        guard loadsWindowOffers else { return }
        screens = RoomEngine.connectedScreens()
        permissionMissing = !AXIsProcessTrusted()
        guard !permissionMissing else { return }
        loading = true
        RoomEngine.loadWindowOffers { result in
            offers = result
            loading = false
        }
    }
}
