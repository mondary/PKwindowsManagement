import AppKit
import SwiftUI

/// State and actions for the Rooms switcher panel.
final class RoomsSwitcherModel: ObservableObject {
    @Published var query = "" { didSet { selection = 0 } }
    @Published var selection = 0
    @Published var isCreating = false
    @Published var newName = ""
    @Published var newAppSelection = Set<String>()

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

    /// Regular apps currently running, by name; our own app is not offered.
    var runningApps: [RoomApp] {
        let ownBundleID = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != ownBundleID }
            .compactMap { app in
                guard let id = app.bundleIdentifier else { return nil }
                return RoomApp(bundleID: id, name: app.localizedName ?? id)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Called each time the panel opens.
    func prepare() {
        query = ""
        selection = 0
        isCreating = store.rooms.isEmpty
        newName = ""
        newAppSelection = []
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
        let engine = engine
        Task { _ = await engine.activate(room) }
        return true
    }

    func deleteSelected() {
        guard let room = selectedRoom else { return }
        store.delete(id: room.id)
        selection = 0
    }

    func toggleNewApp(_ app: RoomApp) {
        if newAppSelection.contains(app.bundleID) {
            newAppSelection.remove(app.bundleID)
        } else {
            newAppSelection.insert(app.bundleID)
        }
    }

    var canCreateRoom: Bool {
        !RoomText.fold(newName).trimmingCharacters(in: .whitespaces).isEmpty && !newAppSelection.isEmpty
    }

    func createRoom() {
        guard canCreateRoom else { return }
        let chosen = runningApps.filter { newAppSelection.contains($0.bundleID) }
        let room = Room(name: newName.trimmingCharacters(in: .whitespaces), apps: chosen)
        store.upsert(room)
        isCreating = false
        newName = ""
        newAppSelection = []
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

    var body: some View {
        VStack(spacing: 12) {
            searchField
            if model.rooms.isEmpty {
                EmptyStateView {
                    model.isCreating = true
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
            Button {
                model.isCreating = true
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

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(room.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.92))
                    .lineLimit(1)
                Text(room.apps.map(\.name).joined(separator: " · "))
                    .font(.system(size: 10.5))
                    .foregroundColor(isSelected ? .white.opacity(0.75) : .white.opacity(0.5))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    ForEach(Array(room.apps.prefix(5).enumerated()), id: \.element.id) { index, app in
                        Image(nsImage: RoomIconCache.icon(for: app))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .offset(x: CGFloat(index) * -3)
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
            RoomLayoutDiagram(apps: room.apps, kind: room.layout)
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
            Text(localizedString("No rooms yet. Create your first room from your running apps."))
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
                Text(localizedString("Running apps"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                Text(String(format: localizedString("%d app(s) selected"), model.newAppSelection.count))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.runningApps) { app in
                        NewAppRow(app: app, isSelected: model.newAppSelection.contains(app.bundleID)) {
                            model.toggleNewApp(app)
                        }
                    }
                }
                .padding(.horizontal, 2)
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
    }
}

private struct NewAppRow: View {
    let app: RoomApp
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: RoomIconCache.icon(for: app))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
            Text(app.name)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.88))
                .lineLimit(1)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15))
                .foregroundColor(isSelected ? Color.accentColor : .white.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
