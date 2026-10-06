import AppKit
import SwiftUI

/// State and actions for the Rooms switcher panel.
final class RoomsSwitcherModel: ObservableObject {
    @Published var query = "" { didSet { selection = 0 } }
    @Published var selection = 0
    @Published var isCreating = false
    @Published var newName = ""
    /// Windows picked for the new room, in click order: index 0 is the main spot.
    @Published var picked: [RoomEngine.WindowOffer] = []
    @Published var offers: [RoomEngine.WindowOffer] = []

    let store: RoomStore
    private let engine: RoomEngine

    init(store: RoomStore = .shared, engine: RoomEngine = RoomEngine()) {
        self.store = store
        self.engine = engine
    }

    var rooms: [Room] {
        store.rooms.filter { $0.matches(query) }
    }

    var selectedRoom: Room? {
        let filtered = rooms
        guard filtered.indices.contains(selection) else { return nil }
        return filtered[selection]
    }

    /// Called each time the panel opens.
    func prepare() {
        query = ""
        selection = 0
        isCreating = false
        newName = ""
        picked = []
        offers = []
    }

    /// Refresh the window list for the picker (AX reads: async so opening the
    /// panel never waits on them).
    func refreshOffers() {
        let engine = engine
        Task { @MainActor in
            self.offers = engine.windowOffers()
        }
    }

    func moveSelection(_ delta: Int) {
        let count = rooms.count
        guard count > 0 else { return }
        selection = ((selection + delta) % count + count) % count
    }

    func cycleLayout(forward: Bool) {
        guard var room = selectedRoom else { return }
        room.layout = forward ? room.layout.next : room.layout.previous
        store.upsert(room)
    }

    /// Fires the activation and returns whether a room was activated.
    @discardableResult
    func activateSelected() -> Bool {
        guard let room = selectedRoom else { return false }
        activate(room: room)
        return true
    }

    private func activate(room: Room) {
        let engine = engine
        let claimed = store.claimedWindowIDs(excluding: room.id)
        Task { _ = await engine.activate(room, claimed: claimed) }
    }

    func deleteSelected() {
        guard let room = selectedRoom else { return }
        store.delete(id: room.id)
        selection = 0
    }

    // MARK: Creation

    /// Click a window: take it out if picked, put it back at the end otherwise.
    func togglePick(_ offer: RoomEngine.WindowOffer) {
        if let index = picked.firstIndex(of: offer) {
            picked.remove(at: index)
        } else {
            picked.append(offer)
        }
    }

    func isPicked(_ offer: RoomEngine.WindowOffer) -> Bool {
        picked.contains(offer)
    }

    var canCreateRoom: Bool {
        !RoomText.fold(newName).trimmingCharacters(in: .whitespaces).isEmpty && !picked.isEmpty
    }

    func createRoom() {
        guard canCreateRoom else { return }
        let windows = picked.map { offer in
            RoomWindow(bundleID: offer.bundleID, appName: offer.appName, title: offer.title, windowID: offer.windowID)
        }
        let room = Room(name: newName.trimmingCharacters(in: .whitespaces), windows: windows)
        store.upsert(room)
        isCreating = false
        newName = ""
        picked = []
        query = ""
        selection = 0
    }
}

/// The Rooms switcher: a compact, Spotlight-like panel. Each room shows its
/// tiling composition as a live miniature; Tab cycles the selected room's
/// layout, Return walks into it, ⌘⌫ deletes it.
struct RoomsSwitcherView: View {
    @ObservedObject var model: RoomsSwitcherModel
    @ObservedObject private var store: RoomStore
    private let onActivateRoom: () -> Void

    init(model: RoomsSwitcherModel, onActivateRoom: @escaping () -> Void) {
        self.model = model
        self.store = model.store
        self.onActivateRoom = onActivateRoom
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isCreating {
                CreationView(model: model)
            } else {
                ListView(model: model, onActivateRoom: onActivateRoom)
            }
        }
        .frame(width: 560, height: 540)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.locale, AppLocalization.currentLanguage.locale)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.08, blue: 0.25).opacity(0.98),
                Color(red: 0.10, green: 0.13, blue: 0.32).opacity(0.97),
                Color(red: 0.02, green: 0.04, blue: 0.14).opacity(0.99)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - List

private struct ListView: View {
    @ObservedObject var model: RoomsSwitcherModel
    let onActivateRoom: () -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            searchField
            if model.rooms.isEmpty {
                EmptyStateView {
                    model.isCreating = true
                    model.refreshOffers()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(model.rooms.enumerated()), id: \.element.id) { index, room in
                            RoomRowView(room: room, isSelected: index == model.selection)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.selection = index
                                    if model.activateSelected() { onActivateRoom() }
                                }
                                .onHover { hovering in
                                    if hovering { model.selection = index }
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            footer
        }
        .padding(16)
        .onAppear { searchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            TextField(localizedString("Search or create a room…"), text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
                .focused($searchFocused)
            Button {
                model.isCreating = true
                model.refreshOffers()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help(localizedString("New Room"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.09))
        )
    }

    private var footer: some View {
        HStack {
            Text(localizedString("↵ open · ⇥ change layout · ⌘⌫ delete"))
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Text("\(model.rooms.count)")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
        }
    }
}

// MARK: - Room row

private struct RoomRowView: View {
    let room: Room
    let isSelected: Bool

    private var subtitle: String {
        let names = room.windows.map { $0.title.isEmpty ? $0.appName : $0.title }
        return names.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(room.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.92))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(isSelected ? .white.opacity(0.75) : .white.opacity(0.5))
                    .lineLimit(3)
                HStack(spacing: 4) {
                    ForEach(Array(room.windows.prefix(5).enumerated()), id: \.element.id) { index, window in
                        Image(nsImage: RoomIconCache.icon(for: window))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .offset(x: CGFloat(index) * -3)
                            .help(window.title.isEmpty ? window.appName : "\(window.appName) — \(window.title)")
                    }
                    if room.windows.count > 5 {
                        Text("+\(room.windows.count - 5)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.top, 1)
                Text(room.layout.title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.6))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.white.opacity(isSelected ? 0.22 : 0.10)))
            }
            Spacer(minLength: 10)
            RoomLayoutDiagram(windows: room.windows, kind: room.layout)
                .frame(width: 150)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.05))
        )
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.white.opacity(0.4))
            Text(localizedString("No rooms yet. Create your first room from your open windows."))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: onCreate) {
                Label(localizedString("New Room"), systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor.opacity(0.8)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 80)
    }
}

// MARK: - Creation

private struct CreationView: View {
    @ObservedObject var model: RoomsSwitcherModel
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                TextField(localizedString("Room name"), text: $model.newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .focused($nameFocused)
                    .onSubmit { if model.canCreateRoom { model.createRoom() } }
                Button {
                    model.isCreating = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .help(localizedString("Cancel"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.09))
            )

            HStack {
                Text(localizedString("Click windows in order — 1 is the main spot"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                Text(String(format: localizedString("%d window(s) selected"), model.picked.count))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }

            if model.offers.isEmpty {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(model.offers) { offer in
                            WindowOfferRow(
                                offer: offer,
                                pickIndex: model.isPicked(offer) ? model.picked.firstIndex(of: offer).map { $0 + 1 } : nil
                            ) {
                                model.togglePick(offer)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            if let first = model.picked.first {
                RoomLayoutDiagram(
                    windows: model.picked.map { RoomWindow(bundleID: $0.bundleID, appName: $0.appName, title: $0.title, windowID: $0.windowID) },
                    kind: .auto
                )
                .frame(width: 220)
            }

            HStack {
                Spacer()
                Button(action: { model.createRoom() }) {
                    Text(localizedString("Create Room"))
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(model.canCreateRoom
                                ? Color.accentColor.opacity(0.85)
                                : Color.white.opacity(0.08))
                        )
                        .foregroundColor(model.canCreateRoom ? .white : .white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!model.canCreateRoom)
            }
        }
        .padding(16)
        .onAppear { nameFocused = true }
    }
}

private struct WindowOfferRow: View {
    let offer: RoomEngine.WindowOffer
    /// Position in the layout (1 = main) when picked, nil otherwise.
    let pickIndex: Int?
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(pickIndex != nil ? Color.accentColor : Color.clear)
                    .frame(width: 22, height: 22)
                if let pickIndex {
                    Text("\(pickIndex)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            Image(nsImage: RoomIconCache.icon(bundleID: offer.bundleID, name: offer.appName))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(offer.title.isEmpty ? offer.appName : offer.title)
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.88))
                    .lineLimit(1)
                if !offer.title.isEmpty {
                    Text(offer.appName)
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(pickIndex != nil ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
