import Foundation

/// How a room arranges its windows on screen.
enum RoomLayoutKind: String, Codable, CaseIterable, Identifiable {
    case auto
    case focus
    case columns
    case grid
    case stack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return localizedString("Auto")
        case .focus: return localizedString("Focus")
        case .columns: return localizedString("Columns")
        case .grid: return localizedString("Grid")
        case .stack: return localizedString("Stack")
        }
    }

    var next: RoomLayoutKind {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var previous: RoomLayoutKind {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + all.count - 1) % all.count]
    }
}

/// One window that belongs to a room, and how to find it again.
/// Modeled on the upstream Rooms app's WindowSlot (MIT).
struct RoomWindow: Codable, Identifiable, Hashable {
    /// Stable slot identity: survives restarts, unlike windowID.
    var id: String
    var bundleID: String
    var appName: String
    /// The window's title when the room was saved (VS Code session name,
    /// browser window name…). Used to find the window again.
    var title: String
    /// The window's identity while it stays open.
    var windowID: UInt32?

    init(bundleID: String, appName: String, title: String, windowID: UInt32? = nil, id: String = UUID().uuidString) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.windowID = windowID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        bundleID = try c.decode(String.self, forKey: .bundleID)
        appName = try c.decodeIfPresent(String.self, forKey: .appName) ?? bundleID
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        windowID = try c.decodeIfPresent(UInt32.self, forKey: .windowID)
    }
}

/// A named set of windows and the layout that arranges them.
struct Room: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var windows: [RoomWindow]
    var layout: RoomLayoutKind
    var createdAt: Date

    init(id: String? = nil, name: String, windows: [RoomWindow], layout: RoomLayoutKind = .auto) {
        self.id = id ?? Room.slug(name)
        self.name = name
        self.windows = windows
        self.layout = layout
        self.createdAt = Date()
    }

    /// Tolerant decoding, with migration of v1 rooms that stored apps.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? Room.slug(name)
        var decoded = try c.decodeIfPresent([RoomWindow].self, forKey: .windows) ?? []
        if decoded.isEmpty {
            // v1 rooms stored whole apps: one slot per app, matched by "any
            // window of this app".
            let apps = try c.decodeIfPresent([RoomApp].self, forKey: .apps) ?? []
            decoded = apps.map { RoomWindow(bundleID: $0.bundleID, appName: $0.name, title: "") }
        }
        windows = decoded
        layout = try c.decodeIfPresent(RoomLayoutKind.self, forKey: .layout) ?? .auto
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    /// Distinct bundle identifiers in slot order (apps the room may need to launch).
    var appBundleIDs: [String] {
        var seen = Set<String>()
        return windows.compactMap { seen.insert($0.bundleID).inserted ? $0.bundleID : nil }
    }

    static func slug(_ s: String) -> String {
        RoomText.fold(s)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "-")
    }

    func matches(_ query: String) -> Bool {
        let q = RoomText.fold(query).trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        if RoomText.fold(name).contains(q) { return true }
        return windows.contains { RoomText.fold($0.title).contains(q) || RoomText.fold($0.appName).contains(q) }
    }
}

/// v1 room app reference, kept for JSON migration.
struct RoomApp: Codable, Hashable {
    var bundleID: String
    var name: String
}

/// Case- and accent-insensitive text folding for search and slugs.
enum RoomText {
    static func fold(_ s: String) -> String {
        let latin = s.applyingTransform(.toLatin, reverse: false) ?? s
        return latin
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
    }
}

/// A live window, reduced to what matching needs.
struct RoomLiveWindow: Hashable {
    var bundleID: String
    var title: String
    var windowID: UInt32?
}

/// Decides which live window fills which slot. Each window is used at most
/// once. Ported from the upstream Rooms app's SlotMatcher (MIT): strongest
/// evidence first — window ID, exact title, similar title, then any window of
/// the app. `claimed` are windows that belong to other rooms: the loose last
/// pass avoids taking one when the app has another window to offer.
enum RoomSlotMatcher {
    static func assign(slots: [RoomWindow], windows: [RoomLiveWindow], claimed: Set<UInt32> = []) -> [Int: Int] {
        var result: [Int: Int] = [:]
        var used = Set<Int>()

        func pass(_ accepts: (RoomWindow, RoomLiveWindow) -> Bool) {
            for (s, slot) in slots.enumerated() where result[s] == nil {
                if let w = windows.indices.first(where: {
                    !used.contains($0) && windows[$0].bundleID == slot.bundleID && accepts(slot, windows[$0])
                }) {
                    result[s] = w
                    used.insert(w)
                }
            }
        }

        pass { slot, win in slot.windowID != nil && slot.windowID == win.windowID }
        pass { slot, win in !slot.title.isEmpty && slot.title == win.title }
        // A title that only looks alike ("Project A" vs "Project B") never
        // takes another room's window.
        pass { slot, win in similar(slot.title, win.title) && !(win.windowID.map(claimed.contains) ?? false) }
        // Browsers change their title with every tab: finally accept any
        // window of the app, a free one first.
        pass { _, win in win.windowID.map { !claimed.contains($0) } ?? true }
        pass { _, _ in true }
        return result
    }

    /// Titles that share a meaningful part: "Report — draft 3" vs "Report — draft 4".
    static func similar(_ a: String, _ b: String) -> Bool {
        let fa = RoomText.fold(a), fb = RoomText.fold(b)
        guard fa.count >= 4, fb.count >= 4 else { return false }
        if fa.contains(fb) || fb.contains(fa) { return true }
        let common = zip(fa, fb).prefix { $0 == $1 }.count
        return common >= min(12, min(fa.count, fb.count) * 2 / 3)
    }
}

/// Rooms persisted as an editable JSON file, like the upstream Rooms app.
final class RoomStore: ObservableObject {
    static let shared = RoomStore()

    @Published private(set) var rooms: [Room] = []

    private struct File: Codable {
        var version = 1
        var rooms: [Room]
    }

    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("PKwindowsManagement", isDirectory: true)
            .appendingPathComponent("rooms.json")
    }

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: Self.defaultURL) else { return }
        if let file = try? JSONDecoder().decode(File.self, from: data) {
            rooms = file.rooms
        }
    }

    func save() {
        let url = Self.defaultURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(File(rooms: rooms)) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func upsert(_ room: Room) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index] = room
        } else {
            rooms.append(room)
        }
        save()
    }

    func delete(id: String) {
        rooms.removeAll { $0.id == id }
        save()
    }

    /// Window IDs claimed by every room except `roomID`.
    func claimedWindowIDs(excluding roomID: String?) -> Set<UInt32> {
        Set(rooms.filter { $0.id != roomID }.flatMap { $0.windows.compactMap(\.windowID) })
    }
}
