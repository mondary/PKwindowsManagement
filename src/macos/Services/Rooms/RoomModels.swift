import Foundation

/// How a room arranges its apps on screen.
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

/// An app that belongs to a room, by bundle identifier.
struct RoomApp: Codable, Identifiable, Hashable {
    var bundleID: String
    var name: String

    var id: String { bundleID }
}

/// A named set of apps and the layout that arranges them.
struct Room: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var apps: [RoomApp]
    var layout: RoomLayoutKind
    var createdAt: Date

    init(id: String? = nil, name: String, apps: [RoomApp], layout: RoomLayoutKind = .auto) {
        self.id = id ?? Room.slug(name)
        self.name = name
        self.apps = apps
        self.layout = layout
        self.createdAt = Date()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? Room.slug(name)
        apps = try c.decodeIfPresent([RoomApp].self, forKey: .apps) ?? []
        layout = try c.decodeIfPresent(RoomLayoutKind.self, forKey: .layout) ?? .auto
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    static func slug(_ s: String) -> String {
        RoomText.fold(s)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "-")
    }

    func matches(_ query: String) -> Bool {
        let q = RoomText.fold(query).trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        let folded = RoomText.fold(name)
        return folded.hasPrefix(q) || folded.contains(q)
    }
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
}
