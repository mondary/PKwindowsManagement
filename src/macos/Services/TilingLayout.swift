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

    var symbolName: String {
        switch self {
        case .automatic: "sparkles.rectangle.stack"
        case .focus: "sidebar.left"
        case .columns: "rectangle.split.3x1"
        case .grid: "square.grid.2x2"
        case .stack: "square.stack.3d.down.right"
        case .dwindle: "rectangle.split.2x2"
        case .monocle: "rectangle.inset.filled"
        case .canvas: "scroll"
        }
    }

    /// Layouts dedicated to standard screen tiling (excludes the horizontal Strip/Canvas).
    static var tilingCases: [TilingLayoutKind] {
        allCases.filter { $0 != .canvas }
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

/// First-class window management mode per display/Space:
/// - `free`: macOS free placement + manual snap/Room scenes
/// - `tiling`: automatic screen tiling (Auto, Focus, Columns, Grid, Stack, Dwindle, Monocle)
/// - `strip`: continuous horizontal scrolling ribbon (OpenCanvas / OmniWM style)
enum WorkspaceWindowMode: String, Codable, CaseIterable, Identifiable {
    case free
    case tiling
    case strip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: localizedString("Free Mode")
        case .tiling: localizedString("Tiling Mode")
        case .strip: localizedString("Strip · OpenCanvas")
        }
    }

    var shortTitle: String {
        switch self {
        case .free: localizedString("Free")
        case .tiling: localizedString("Tiling")
        case .strip: localizedString("Strip")
        }
    }

    var subtitle: String {
        switch self {
        case .free: localizedString("Position windows freely, snap on demand or restore saved Room positions.")
        case .tiling: localizedString("Automatically arrange open and new windows on this screen.")
        case .strip: localizedString("Continuous horizontal ribbon (OpenCanvas / OmniWM) with minimap and trackpad scroll.")
        }
    }

    var symbolName: String {
        switch self {
        case .free: "macwindow.on.rectangle"
        case .tiling: "rectangle.split.3x1"
        case .strip: "rectangle.3.group.fill"
        }
    }
}

/// Persisted independently per connected display and native desktop Space.
struct TilingWorkspaceProfile: Codable, Equatable {
    var mode: TilingMode = .free
    var layout: TilingLayoutKind = .automatic
    var preferredTilingLayout: TilingLayoutKind? = nil
    var activeRoomID: String? = nil

    init(mode: TilingMode = .free,
         layout: TilingLayoutKind = .automatic,
         preferredTilingLayout: TilingLayoutKind? = nil,
         activeRoomID: String? = nil) {
        self.mode = mode
        self.layout = layout
        self.preferredTilingLayout = preferredTilingLayout
        self.activeRoomID = activeRoomID
    }

    var workspaceMode: WorkspaceWindowMode {
        get {
            guard mode == .tiling else { return .free }
            return layout == .canvas ? .strip : .tiling
        }
        set {
            setWorkspaceMode(newValue)
        }
    }

    var effectiveTilingLayout: TilingLayoutKind {
        if layout != .canvas { return layout }
        if let preferredTilingLayout, preferredTilingLayout != .canvas {
            return preferredTilingLayout
        }
        return .automatic
    }

    mutating func setWorkspaceMode(_ newMode: WorkspaceWindowMode) {
        switch newMode {
        case .free:
            if mode == .tiling && layout != .canvas {
                preferredTilingLayout = layout
            }
            mode = .free
        case .tiling:
            mode = .tiling
            activeRoomID = nil
            if layout == .canvas {
                layout = effectiveTilingLayout
            } else {
                preferredTilingLayout = layout
            }
        case .strip:
            if layout != .canvas {
                preferredTilingLayout = layout
            }
            mode = .tiling
            layout = .canvas
            activeRoomID = nil
        }
    }

    mutating func selectTilingLayout(_ newLayout: TilingLayoutKind) {
        if newLayout == .canvas {
            setWorkspaceMode(.strip)
        } else {
            preferredTilingLayout = newLayout
            layout = newLayout
            mode = .tiling
            activeRoomID = nil
        }
    }

    mutating func cycleWorkspaceMode() {
        switch workspaceMode {
        case .free: setWorkspaceMode(.tiling)
        case .tiling: setWorkspaceMode(.strip)
        case .strip: setWorkspaceMode(.free)
        }
    }
}

struct TilingWorkspaceKey: Hashable, Codable {
    let displayUUID: String
    let spaceID: UInt64

    var storageKey: String { "\(displayUUID):\(spaceID)" }
}

struct TilingWorkspaceSnapshot: Equatable, Identifiable {
    let key: TilingWorkspaceKey
    let displayID: CGDirectDisplayID
    let displayName: String
    let profile: TilingWorkspaceProfile

    var id: String { key.storageKey }
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
