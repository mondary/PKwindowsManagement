import CoreGraphics
import Foundation

@main
enum TilingLayoutChecks {
    static func main() {
        assert(TilingLayoutKind.allCases.count == 8)
        assert(Set(TilingLayoutKind.allCases.map(\.rawValue)).count == 8)
        assert(TilingLayoutKind.allCases.filter { $0.roomLayout == nil } == [.canvas])
        assert(TilingLayoutKind.allCases.compactMap(\.roomLayout).count == RoomLayoutKind.allCases.count)

        // Future-window behavior remains defined independently of today's count.
        let area = CGRect(x: 0, y: 0, width: 1440, height: 900)
        for kind in TilingLayoutKind.allCases {
            for count in 1...6 {
                let frames = TilingLayoutGeometry.frames(kind: kind, count: count, in: area,
                    selectedIndex: count - 1)
                assert(frames.count == count, "\(kind) must place \(count) windows")
                assert(frames.allSatisfy { $0.width > 0 && $0.height > 0 })
            }
        }
        for count in 1...6 {
            let resolved = TilingLayoutGeometry.resolvedKind(kind: .automatic, count: count, in: area)
            assert(resolved != .automatic, "Auto preview must show its resolved rule")
            assert(resolved.roomLayout != nil)
        }
        let sixWindowFrames = Dictionary(uniqueKeysWithValues: TilingLayoutKind.allCases.map {
            ($0, TilingLayoutGeometry.frames(kind: $0, count: 6, in: area, selectedIndex: 5))
        })
        for kind in [TilingLayoutKind.focus, .columns, .grid, .stack, .dwindle, .monocle, .canvas] {
            for other in [TilingLayoutKind.focus, .columns, .grid, .stack, .dwindle, .monocle, .canvas]
            where kind != other {
                assert(sixWindowFrames[kind] != sixWindowFrames[other], "\(kind) and \(other) must stay distinct")
            }
        }
        let canvasVisible = TilingLayoutGeometry.canvasVisibleIndices(count: 6,
            in: CGRect(x: 0, y: 0, width: 340, height: 196), selectedIndex: 5)
        assert(canvasVisible.contains(5), "Canvas follows the newest selected window")
        assert(canvasVisible.count < 6, "Canvas preview exposes a viewport over its minimap")

        let defaultsName = "TilingLayoutChecks-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let one = TilingWorkspaceKey(displayUUID: "display-a", spaceID: 42)
        let otherDisplay = TilingWorkspaceKey(displayUUID: "display-b", spaceID: 42)
        let otherSpace = TilingWorkspaceKey(displayUUID: "display-a", spaceID: 43)
        assert(one != otherDisplay && one != otherSpace)

        let first = TilingWorkspaceProfile(mode: .tiling, layout: .dwindle)
        let second = TilingWorkspaceProfile(mode: .free, layout: .grid)
        assert(TilingWorkspaceProfiles.update(first, for: one, defaults: defaults))
        assert(TilingWorkspaceProfiles.update(second, for: otherSpace, defaults: defaults))
        let loaded = TilingWorkspaceProfiles.load(defaults: defaults)
        assert(TilingWorkspaceProfiles.profile(for: one, in: loaded) == first)
        assert(TilingWorkspaceProfiles.profile(for: otherSpace, in: loaded) == second)
        assert(TilingWorkspaceProfiles.profile(for: otherDisplay, in: loaded) == TilingWorkspaceProfile())

        // Codable raw names stay stable for future backups/migrations.
        for kind in TilingLayoutKind.allCases {
            let data = try! JSONEncoder().encode(kind)
            assert(try! JSONDecoder().decode(TilingLayoutKind.self, from: data) == kind)
        }
        print("Tiling layout checks passed: eight persistent rules, future windows and per-display/Space profiles")
    }
}
