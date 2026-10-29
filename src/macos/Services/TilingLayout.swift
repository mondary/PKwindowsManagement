import CoreGraphics
import Foundation

/// The layout rule selected for a native display/Space. These are algorithms,
/// not a menu filtered by the current room's window count: each remains active
/// as more windows arrive. Canvas is the existing scrollable-grid engine.
enum TilingLayoutKind: String, Codable, CaseIterable, Identifiable {
    case automatic
    case focus
    case columns
    case grid
    case stack
    case dwindle
    case monocle
    case canvas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: localizedString("Automatic")
        case .focus: localizedString("Focus")
        case .columns: localizedString("Columns")
        case .grid: localizedString("Grid")
        case .stack: localizedString("Stack")
        case .dwindle: localizedString("Dwindle")
        case .monocle: localizedString("Monocle")
        case .canvas: localizedString("Horizontal Canvas")
        }
    }

    var description: String {
        switch self {
        case .automatic: localizedString("Automatically choose a comfortable arrangement as windows arrive.")
        case .focus: localizedString("Keep one large main window and arrange the others beside it.")
        case .columns: localizedString("Give each window a column; new windows extend the row.")
        case .grid: localizedString("Rebalance windows into equal cells as the grid grows.")
        case .stack: localizedString("Keep a main window beside overlapping cards with accessible title bars.")
        case .dwindle: localizedString("Split the remaining area recursively as each window arrives.")
        case .monocle: localizedString("Show the selected window full-size; cycle through the others.")
        case .canvas: localizedString("Scroll a two-row window strip horizontally, with a minimap.")
        }
    }

    /// Existing Room geometry is also used by the continuous engine and its
    /// previews. `.canvas` is handled by CanvasLayout instead.
    var roomLayout: RoomLayoutKind? {
        switch self {
        case .automatic: .auto
        case .focus: .focus
        case .columns: .columns
        case .grid: .grid
        case .stack: .stack
        case .dwindle: .dwindle
        case .monocle: .monocle
        case .canvas: nil
        }
    }
}

enum TilingMode: String, Codable {
    case free
    case tiling
}

/// Persisted independently per connected display and native desktop Space.
struct TilingWorkspaceProfile: Codable, Equatable {
    var mode: TilingMode = .free
    var layout: TilingLayoutKind = .automatic
}

struct TilingWorkspaceKey: Hashable, Codable {
    let displayUUID: String
    let spaceID: UInt64

    var storageKey: String { "\(displayUUID):\(spaceID)" }
}

struct TilingWorkspaceSnapshot: Equatable {
    let key: TilingWorkspaceKey
    let displayID: CGDirectDisplayID
    let displayName: String
    let profile: TilingWorkspaceProfile
}

enum TilingLayoutGeometry {
    static func resolvedKind(kind: TilingLayoutKind, count: Int, in area: CGRect) -> TilingLayoutKind {
        guard kind == .automatic,
              let resolved = TilingLayoutKind(rawValue: RoomTiler.autoKind(count: count, in: area).rawValue)
        else { return kind }
        return resolved
    }

    static func frames(kind: TilingLayoutKind, count: Int, in area: CGRect,
                       selectedIndex: Int? = nil) -> [CGRect] {
        guard count > 0 else { return [] }
        let resolved = resolvedKind(kind: kind, count: count, in: area)
        if let roomLayout = resolved.roomLayout {
            var frames = RoomTiler.frames(count: count, kind: roomLayout, in: area)
            let heroLayout: Bool
            switch resolved {
            case .focus, .stack: heroLayout = true
            case .automatic:
                let automatic = RoomTiler.autoKind(count: count, in: area)
                heroLayout = automatic == .focus || automatic == .stack
            default: heroLayout = false
            }
            if heroLayout, let selectedIndex, frames.indices.contains(selectedIndex), selectedIndex != 0 {
                let order = [selectedIndex] + frames.indices.filter { $0 != selectedIndex }
                var assigned = frames
                for (slot, window) in order.enumerated() { assigned[window] = frames[slot] }
                frames = assigned
            }
            return frames
        }

        let geometry = CanvasLayout.Geometry(area: area, rows: 2)
        let columns = CanvasLayout.columns(halfHeight: Array(repeating: false, count: count))
        let width = geometry.defaultColumnWidth(columns: CanvasLayout.preferredColumns(forAreaWidth: area.width))
        let widths = Array(repeating: width, count: columns.count)
        let viewport: CGFloat
        if let selectedIndex,
           let selectedSlot = CanvasLayout.slot(index: selectedIndex, columns: columns) {
            viewport = CanvasLayout.fitViewport(index: selectedSlot.column, widths: widths,
                geometry: geometry, current: 0)
        } else {
            viewport = 0
        }
        return (0..<count).compactMap { index in
            guard let slot = CanvasLayout.slot(index: index, columns: columns) else { return nil }
            return CanvasLayout.placement(column: slot.column, row: slot.row, widths: widths,
                geometry: geometry, viewport: viewport, otherDisplays: [], rows: columns[slot.column].rows).frame
        }
    }

    static func canvasVisibleIndices(count: Int, in area: CGRect, selectedIndex: Int?) -> Set<Int> {
        guard count > 0 else { return [] }
        let geometry = CanvasLayout.Geometry(area: area, rows: 2)
        let columns = CanvasLayout.columns(halfHeight: Array(repeating: false, count: count))
        let width = geometry.defaultColumnWidth(columns: CanvasLayout.preferredColumns(forAreaWidth: area.width))
        let widths = Array(repeating: width, count: columns.count)
        let origins = CanvasLayout.canvasOrigins(widths: widths)
        let selectedColumn = selectedIndex.flatMap { CanvasLayout.slot(index: $0, columns: columns)?.column }
        let viewport = selectedColumn.map {
            CanvasLayout.fitViewport(index: $0, widths: widths, geometry: geometry, current: 0)
        } ?? 0
        return Set((0..<count).filter { index in
            guard let slot = CanvasLayout.slot(index: index, columns: columns) else { return false }
            let minX = origins[slot.column]
            let maxX = minX + widths[slot.column]
            return maxX > viewport && minX < viewport + geometry.contentWidth
        })
    }
}

enum TilingWorkspaceProfiles {
    static let defaultsKey = "continuous-tiling-workspace-profiles-v1"

    static func load(defaults: UserDefaults = .standard) -> [String: TilingWorkspaceProfile] {
        guard let data = defaults.data(forKey: defaultsKey),
              let profiles = try? JSONDecoder().decode([String: TilingWorkspaceProfile].self, from: data)
        else { return [:] }
        return profiles
    }

    @discardableResult
    static func replace(_ profiles: [String: TilingWorkspaceProfile], defaults: UserDefaults = .standard) -> Bool {
        guard let data = try? JSONEncoder().encode(profiles) else { return false }
        defaults.set(data, forKey: defaultsKey)
        return true
    }

    static func profile(for key: TilingWorkspaceKey, in profiles: [String: TilingWorkspaceProfile]) -> TilingWorkspaceProfile {
        profiles[key.storageKey] ?? TilingWorkspaceProfile()
    }

    @discardableResult
    static func update(_ profile: TilingWorkspaceProfile, for key: TilingWorkspaceKey,
                       defaults: UserDefaults = .standard) -> Bool {
        var profiles = load(defaults: defaults)
        profiles[key.storageKey] = profile
        guard let data = try? JSONEncoder().encode(profiles) else { return false }
        defaults.set(data, forKey: defaultsKey)
        return true
    }
}
