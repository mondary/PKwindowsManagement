import AppKit
import SwiftUI

/// Persistent entry point for Rooms: the saved projects are visible without
/// knowing the switcher's global shortcut. Shares the existing rooms.json.
struct RoomsPreferencesView: View {
    @ObservedObject private var store: RoomStore
    @StateObject private var model: RoomsSwitcherModel
    @State private var query = ""
    @State private var editingRoom: Room?
    @State private var deletedRoom: Room?

    init(store: RoomStore = .shared) {
        self.store = store
        _model = StateObject(wrappedValue: RoomsSwitcherModel(store: store))
    }

    private var visibleRooms: [Room] { store.rooms.filter { $0.matches(query) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Rooms", systemImage: "rectangle.3.group").font(.title2.bold())
                        Text(localizedString("Your projects, their windows and their layouts."))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(localizedString("New Room")) {
                        editingRoom = Room(name: "", windows: [])
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack {
                    Button(localizedString("Open Rooms")) { RoomsOverlayController.shared.show() }
                    Text("⌃⌥R").font(.body.monospaced()).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: localizedString("%d room(s)"), store.rooms.count))
                        .foregroundStyle(.secondary)
                }
                Text(localizedString("Choose windows in order, select a layout and a screen, then open your project in one click. Minimize puts its windows away without closing them."))
                    .font(.callout).foregroundStyle(.secondary)

                if let deletedRoom {
                    HStack {
                        Text(String(format: localizedString("Room removed: %@"), deletedRoom.name))
                        Spacer()
                        Button(localizedString("Undo")) {
                            store.upsert(deletedRoom)
                            self.deletedRoom = nil
                        }
                    }
                    .padding(12)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                if !store.rooms.isEmpty {
                    TextField(localizedString("Search rooms…"), text: $query)
                        .textFieldStyle(.roundedBorder)
                }
                if visibleRooms.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localizedString(store.rooms.isEmpty ? "No rooms yet. Create your first room from your open windows." : "No matching rooms."))
                            .font(.headline)
                        if store.rooms.isEmpty {
                            Text(localizedString("Open the apps for your project, click New Room, and select the windows to keep together."))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                }
                ForEach(visibleRooms) { room in
                    roomCard(room)
                }
                Text(localizedString("Rooms use ordinary app windows. A saved room is a project layout, not a macOS desktop."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .onAppear { model.prepare() }
        .sheet(item: $editingRoom) { room in
            RoomEditorView(room: room, store: store)
        }
    }

    private func roomCard(_ room: Room) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(room.name).font(.headline)
                    Text(room.windows.map { $0.title.isEmpty ? $0.appName : $0.title }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    HStack {
                        Text(room.layout.title)
                        Text("·")
                        Text(model.screenName(for: room) ?? localizedString("Screen under pointer"))
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                RoomLayoutDiagram(windows: room.windows, kind: room.layout).frame(width: 150)
                    .accessibilityLabel(room.layout.title)
            }
            HStack {
                Button(localizedString("Open Room")) { model.activate(room: room) }
                    .buttonStyle(.borderedProminent)
                Button(localizedString("Edit Room")) { editingRoom = room }
                Button(localizedString("Minimize Room")) { model.minimize(room: room) }
                Spacer()
                Button {
                    editingRoom = Room(
                        name: String(format: localizedString("%@ — copy"), room.name),
                        windows: room.windows.map {
                            RoomWindow(bundleID: $0.bundleID, appName: $0.appName,
                                       title: $0.title, windowID: $0.windowID)
                        },
                        layout: room.layout, displayUUID: room.displayUUID
                    )
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .help(localizedString("Duplicate Room"))
                .accessibilityLabel(localizedString("Duplicate Room"))
                Button {
                    deletedRoom = room
                    store.delete(id: room.id)
                } label: {
                    Image(systemName: "trash")
                }
                .help(localizedString("Delete Room"))
                .accessibilityLabel(localizedString("Delete Room"))
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// A draft keeps existing slot identities, unavailable windows and room metadata
/// until Save. Cancel never alters the stored project.
struct RoomEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: RoomStore
    @State private var draft: Room
    @State private var offers: [RoomEngine.WindowOffer] = []
    @State private var screens: [RoomEngine.ScreenOption] = []
    @State private var loading = false
    @State private var permissionMissing = false
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizedString(isNew ? "New Room" : "Edit Room")).font(.title2.bold())
            TextField(localizedString("Room name"), text: $draft.name).textFieldStyle(.roundedBorder)
            Picker(localizedString("Screen"), selection: $draft.displayUUID) {
                Text(localizedString("Screen under pointer")).tag(String?.none)
                ForEach(screens) { screen in Text(screen.name).tag(Optional(screen.uuid)) }
                if let uuid = draft.displayUUID, !screens.contains(where: { $0.uuid == uuid }) {
                    Text(localizedString("Disconnected screen")).tag(Optional(uuid))
                }
            }
            layoutChoices
            Text(localizedString("Click windows in order — 1 is the main spot"))
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(format: localizedString("%d window(s) selected"), draft.windows.count)).font(.headline)
                    ForEach(Array(draft.windows.enumerated()), id: \.element.id) { index, window in
                        selectedWindow(window, index: index)
                    }
                    Divider().padding(.vertical, 4)
                    HStack {
                        Text(localizedString("Available windows")).font(.headline)
                        Spacer()
                        if loading { ProgressView().controlSize(.small) }
                        Button(localizedString("Refresh")) { refresh() }.disabled(loading)
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
                            windowLabel(name: offer.appName, title: offer.title, bundleID: offer.bundleID)
                            Spacer()
                            Button(localizedString(contains(offer) ? "Selected" : "Add")) {
                                draft.windows.append(RoomWindow(bundleID: offer.bundleID, appName: offer.appName,
                                                                title: offer.title, windowID: offer.windowID))
                            }
                            .disabled(contains(offer))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Divider()
            HStack {
                RoomLayoutDiagram(windows: draft.windows, kind: draft.layout).frame(width: 110)
                Spacer()
                Button(localizedString("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(localizedString("Save Room")) {
                    draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.upsert(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 620, height: 580)
        .onAppear { refresh() }
    }

    private var layoutChoices: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedString("Layout")).font(.headline)
            HStack(spacing: 8) {
                ForEach(RoomLayoutKind.allCases) { kind in
                    Button { draft.layout = kind } label: {
                        VStack(spacing: 6) {
                            RoomLayoutDiagram(windows: draft.windows, kind: kind)
                            Text(kind.title).font(.caption)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(draft.layout == kind ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(draft.layout == kind ? Color.accentColor : Color.clear, lineWidth: 2))
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
            Text("\(index + 1)").font(.body.monospacedDigit()).frame(width: 22)
            windowLabel(name: window.appName, title: window.title, bundleID: window.bundleID)
            Spacer()
            Button { draft.windows.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }
                .disabled(index == 0).accessibilityLabel(localizedString("Move up"))
            Button { draft.windows.swapAt(index, index + 1) } label: { Image(systemName: "arrow.down") }
                .disabled(index == draft.windows.count - 1).accessibilityLabel(localizedString("Move down"))
            Button { draft.windows.remove(at: index) } label: { Image(systemName: "minus.circle") }
                .accessibilityLabel(localizedString("Remove window"))
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func windowLabel(name: String, title: String, bundleID: String) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: RoomIconCache.icon(bundleID: bundleID, name: name))
                .resizable().frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.isEmpty ? name : title).lineLimit(1)
                if !title.isEmpty { Text(name).font(.caption).foregroundStyle(.secondary) }
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
