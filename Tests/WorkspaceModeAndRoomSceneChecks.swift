import CoreGraphics
import Foundation

// Standalone checks for the Free/Tiling/Strip workspace modes and the Rooms
// saved-position scene model (compiled with TilingLayout.swift,
// RoomModels.swift, RoomTiler.swift and Localization.swift).

@main
enum WorkspaceModeAndRoomSceneChecks {
    static func main() {
        workspaceModeTransitions()
        profileCompatibility()
        normalizedRectGeometry()
        roomSavedFrameMigration()
        roomResolvedFrames()
        roomSlotMatcherStaysStable()
        print("Workspace mode & room scene checks passed")
    }

    // MARK: - WorkspaceWindowMode

    private static func workspaceModeTransitions() {
        assert(WorkspaceWindowMode.allCases == [.free, .tiling, .strip])

        var profile = TilingWorkspaceProfile()
        assert(profile.workspaceMode == .free)

        profile.setWorkspaceMode(.tiling)
        assert(profile.mode == .tiling && profile.workspaceMode == .tiling)
        assert(profile.layout != .canvas)
        profile.selectTilingLayout(.dwindle)
        assert(profile.workspaceMode == .tiling && profile.effectiveTilingLayout == .dwindle)

        // Tiling -> Strip keeps the preferred tiling layout for the way back.
        profile.setWorkspaceMode(.strip)
        assert(profile.workspaceMode == .strip)
        assert(profile.layout == .canvas)
        assert(profile.preferredTilingLayout == .dwindle)
        assert(profile.effectiveTilingLayout == .dwindle)

        // Strip -> Tiling restores the preferred layout.
        profile.setWorkspaceMode(.tiling)
        assert(profile.workspaceMode == .tiling)
        assert(profile.layout == .dwindle)

        // Tiling -> Free remembers the layout, Free -> Tiling restores it.
        profile.setWorkspaceMode(.free)
        assert(profile.workspaceMode == .free && profile.mode == .free)
        profile.setWorkspaceMode(.tiling)
        assert(profile.effectiveTilingLayout == .dwindle)

        // Selecting the Canvas layout is the Strip mode.
        profile.selectTilingLayout(.canvas)
        assert(profile.workspaceMode == .strip)

        // Cycle: Free -> Tiling -> Strip -> Free.
        var cycled = TilingWorkspaceProfile()
        cycled.cycleWorkspaceMode()
        assert(cycled.workspaceMode == .tiling)
        cycled.cycleWorkspaceMode()
        assert(cycled.workspaceMode == .strip)
        cycled.cycleWorkspaceMode()
        assert(cycled.workspaceMode == .free)
    }

    private static func profileCompatibility() {
        // A profile encoded before preferredTilingLayout/activeRoomID existed
        // still decodes with safe defaults.
        let legacy = """
        {"mode":"tiling","layout":"grid"}
        """.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(TilingWorkspaceProfile.self, from: legacy)
        assert(decoded.mode == .tiling && decoded.layout == .grid)
        assert(decoded.preferredTilingLayout == nil && decoded.activeRoomID == nil)
        assert(decoded.workspaceMode == .tiling)

        let legacyFree = """
        {"mode":"free","layout":"canvas"}
        """.data(using: .utf8)!
        let free = try! JSONDecoder().decode(TilingWorkspaceProfile.self, from: legacyFree)
        assert(free.workspaceMode == .free, "Free wins even when the stored layout is Canvas")

        // Round-trip with the new fields.
        var profile = TilingWorkspaceProfile()
        profile.setWorkspaceMode(.strip)
        profile.activeRoomID = "room-42"
        let data = try! JSONEncoder().encode(profile)
        let roundTrip = try! JSONDecoder().decode(TilingWorkspaceProfile.self, from: data)
        assert(roundTrip == profile)
    }

    // MARK: - RoomNormalizedRect

    private static func normalizedRectGeometry() {
        let area = CGRect(x: 100, y: 50, width: 1000, height: 800)
        let frame = CGRect(x: 300, y: 250, width: 400, height: 320)
        let normalized = RoomNormalizedRect(frame: frame, in: area)
        assert(normalized.x == 0.2 && normalized.y == 0.25)
        assert(normalized.width == 0.4 && normalized.height == 0.4)

        let restored = normalized.rect(in: area)
        assert(restored == frame, "capture/restore is exact for in-area frames")

        // Out-of-bounds frames are clamped to stay usable on any screen size.
        let clamped = RoomNormalizedRect(x: -2, y: 3, width: 4, height: 0.01)
        assert(clamped.x == 0 && clamped.y == 0.96)
        assert(clamped.width == 1 && clamped.height == 0.08)
        let clampedRect = clamped.rect(in: area, minimumSize: CGSize(width: 24, height: 20))
        assert(area.contains(clampedRect))
        assert(clampedRect.width >= 24 && clampedRect.height >= 20)

        // Frames adapt to a differently sized fallback screen.
        let otherArea = CGRect(x: -1920, y: 32, width: 1920, height: 1080)
        let adapted = normalized.rect(in: otherArea)
        assert(otherArea.contains(adapted))
        assert(abs(adapted.width - 1920 * 0.4) <= 1)
        assert(abs(adapted.height - 1080 * 0.4) <= 1)

        // Codable stability.
        let data = try! JSONEncoder().encode(normalized)
        assert(try! JSONDecoder().decode(RoomNormalizedRect.self, from: data) == normalized)
    }

    // MARK: - Room migration & saved frames

    private static func roomSavedFrameMigration() {
        // A v1 room (apps only, no windows) still decodes.
        let v1 = """
        {"id":"legacy","name":"Legacy","apps":[{"bundleID":"com.example.app","name":"Example"}],"layout":"focus"}
        """.data(using: .utf8)!
        let migrated = try! JSONDecoder().decode(Room.self, from: v1)
        assert(migrated.windows.count == 1 && migrated.windows[0].bundleID == "com.example.app")
        assert(!migrated.useSavedFrames && migrated.handoffPolicy == .adoptWorkspaceMode)
        assert(!migrated.hasSavedFrames)

        // A room saved before savedFrame/useSavedFrames/handoffPolicy existed.
        let v2 = """
        {"id":"old","name":"Old","windows":[{"id":"w1","bundleID":"com.a","appName":"A","title":"Doc"}],"layout":"grid","focusedWindowIndex":0,"createdAt":700000000}
        """.data(using: .utf8)!
        let old = try! JSONDecoder().decode(Room.self, from: v2)
        assert(old.useSavedFrames == false)
        assert(old.handoffPolicy == .adoptWorkspaceMode)
        assert(old.windows[0].savedFrame == nil)

        // A room with recorded frames defaults to keeping them.
        let withFrames = """
        {"id":"scene","name":"Scene","windows":[{"id":"w1","bundleID":"com.a","appName":"A","title":"Doc","savedFrame":{"x":0.1,"y":0.1,"width":0.5,"height":0.5}}],"layout":"auto"}
        """.data(using: .utf8)!
        let scene = try! JSONDecoder().decode(Room.self, from: withFrames)
        assert(scene.useSavedFrames && scene.handoffPolicy == .keepRoomPositions)
        assert(scene.hasSavedFrames)

        // Round-trip keeps every new field and never writes the legacy apps key.
        var room = Room(name: "Studio", windows: [
            RoomWindow(bundleID: "com.a", appName: "A", title: "Doc",
                       savedFrame: RoomNormalizedRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6))
        ], layout: .focus, displayUUID: "display-a", useSavedFrames: true,
           handoffPolicy: .keepRoomPositions)
        room.focusedWindowIndex = 0
        let data = try! JSONEncoder().encode(room)
        let json = String(data: data, encoding: .utf8)!
        assert(!json.contains("\"apps\""))
        let roundTrip = try! JSONDecoder().decode(Room.self, from: data)
        assert(roundTrip.useSavedFrames == room.useSavedFrames)
        assert(roundTrip.handoffPolicy == room.handoffPolicy)
        assert(roundTrip.windows[0].savedFrame == room.windows[0].savedFrame)
        assert(roundTrip.displayUUID == "display-a")
    }

    private static func roomResolvedFrames() {
        let area = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let saved = RoomNormalizedRect(x: 0.5, y: 0.25, width: 0.4, height: 0.5)
        let room = Room(name: "Mixed", windows: [
            RoomWindow(bundleID: "com.a", appName: "A", title: "One", savedFrame: saved),
            RoomWindow(bundleID: "com.b", appName: "B", title: "Two")
        ], layout: .columns, useSavedFrames: true, handoffPolicy: .keepRoomPositions)

        let frames = room.resolvedFrames(in: area)
        assert(frames.count == 2)
        assert(frames[0] == saved.rect(in: area))
        let fallback = RoomTiler.frames(count: 2, kind: .columns, in: area)
        assert(frames[1] == fallback[1], "a slot without a recorded frame falls back to the tiler")

        // With saved frames disabled, the dynamic layout owns every slot.
        var dynamic = room
        dynamic.useSavedFrames = false
        assert(dynamic.resolvedFrames(in: area) == fallback)

        // Empty rooms stay empty.
        assert(Room(name: "Empty", windows: []).resolvedFrames(in: area).isEmpty)
    }

    private static func roomSlotMatcherStaysStable() {
        let slots = [
            RoomWindow(bundleID: "com.a", appName: "A", title: "Report", windowID: 7),
            RoomWindow(bundleID: "com.b", appName: "B", title: "")
        ]
        let windows = [
            RoomLiveWindow(bundleID: "com.a", title: "Report", windowID: 7),
            RoomLiveWindow(bundleID: "com.b", title: "Anything", windowID: 9)
        ]
        let assignment = RoomSlotMatcher.assign(slots: slots, windows: windows)
        assert(assignment[0] == 0, "window ID is the strongest match")
        assert(assignment[1] == 1)
    }
}
