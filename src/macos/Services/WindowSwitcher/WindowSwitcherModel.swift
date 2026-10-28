import AppKit
import ApplicationServices
import Combine

/// Tone of the picker's status message.
enum MessageKind {
    case info
    case success
    case error
}

/// Actions offered by the ⌘K room menu in the picker.
enum RoomAction: CaseIterable {
    case open
    case minimize
    case rename
    case cycleLayout
    case duplicate
    case delete

    var title: String {
        switch self {
        case .open: localizedString("Open Room")
        case .minimize: localizedString("Minimize Room")
        case .rename: localizedString("Rename")
        case .cycleLayout: localizedString("Change layout")
        case .duplicate: localizedString("Duplicate")
        case .delete: localizedString("Delete Room")
        }
    }

    var symbolName: String {
        switch self {
        case .open: return "arrow.up.forward"
        case .minimize: return "arrow.down.to.line"
        case .rename: return "pencil"
        case .cycleLayout: return "rectangle.grid.2x2"
        case .duplicate: return "plus.square.on.square"
        case .delete: return "trash"
        }
    }
}

struct ForceQuitConfirmation: Identifiable, Equatable {
    let id: WindowSwitcherID
    let appName: String
    let launchedAt: Date?
}

/// UI state lives on main, AX inventory and capture run off the event tap.
final class WindowSwitcherModel: ObservableObject {
    @Published private(set) var items: [WindowSwitcherItem] = []
    /// Running apps without listed windows (Dock) and menu-bar apps.
    @Published private(set) var processItems: [WindowSwitcherItem] = []
    @Published var query = "" {
        didSet {
            selectedTarget = WindowSwitcherState.selection(in: navigationTargets, keeping: selectedTarget)
            roomSelection = 0
            launcherSelection = 0
            fallbackSelection = 0
            loadLauncherAppsIfNeeded()
        }
    }
    @Published private(set) var selectedTarget: WindowSwitcherTarget?
    /// Compatibility accessors for window/app controls that do not act on Rooms.
    var selectedID: WindowSwitcherID? {
        get { if case .item(let id) = selectedTarget { return id }; return nil }
        set { selectedTarget = newValue.map(WindowSwitcherTarget.item) }
    }
    var selectedRoomID: String? {
        guard case .room(let id) = selectedTarget else { return nil }
        return id
    }
    @Published private(set) var isLoading = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var previewsGranted = false
    @Published private(set) var images: [WindowSwitcherID: NSImage] = [:]
    @Published private(set) var completedPreviews = Set<WindowSwitcherID>()
    @Published private(set) var generation = UUID()
    @Published var message = ""
    @Published var messageKind: MessageKind = .info
    @Published private(set) var closingID: WindowSwitcherID?
    @Published private(set) var quittingPID: pid_t?
    @Published private(set) var quittingName: String?
    @Published private(set) var isForceQuitting = false
    @Published private(set) var forceQuitConfirmation: ForceQuitConfirmation?
    /// Room creation: pick windows in order; index 0 is the main spot.
    @Published var isCreatingRoom = false
    @Published var roomName = ""
    @Published var creationLayout: RoomLayoutKind = .auto
    @Published private(set) var roomPicks: [WindowSwitcherID] = []
    /// Installed applications shown when the query matches no window.
    @Published private(set) var launcherApps: [LaunchableApp] = []
    @Published private(set) var isLoadingLauncherApps = false
    @Published private(set) var roomSelection = 0
    @Published private(set) var launcherSelection = 0
    @Published private(set) var fallbackSelection = 0
    /// ⌘K room menu state.
    @Published private(set) var roomActionTargetID: String?
    @Published private(set) var roomActionSelection = 0
    @Published var renamingRoomID: String?
    @Published var renameText = ""
    var onReady: (() -> Void)?
    var columns = 3
    /// Column counts of the Applications and Rooms grids, computed from the
    /// panel width by `present()` so vertical arrows land on real rows.
    var appColumns = 9
    var roomColumns = 3
    var cardHeight: CGFloat = 210
    var isBusy: Bool { closingID != nil || quittingPID != nil }
    private(set) var icons: [pid_t: NSImage] = [:]
    let roomStore: RoomStore
    private var candidates: [WindowSwitcherID: WindowSwitcherInventory.Candidate] = [:]
    private var focusedID: WindowSwitcherID?
    private var processLaunchedAt: [Int32: Date] = [:]
    /// Synthetic pid → bundle identifier, for apps NSWorkspace reports without
    /// a usable pid (Steam reports -1): actions resolve the live instance.
    private var processBundleIDs: [Int32: String] = [:]
    private var inventoryTask: Task<WindowSwitcherInventory.Snapshot, Never>?
    private var loadingTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var closeTask: Task<WindowCloseRequest.Result, Never>?
    private var closeResultTask: Task<Void, Never>?
    private var quitTask: Task<WindowQuitRequest.Result, Never>?
    private var quitResultTask: Task<Void, Never>?
    private var capture = WindowThumbnailCapture()
    private var pendingPreviews: [WindowSwitcherID] = []
    private var attemptedPreviews = Set<WindowSwitcherID>()
    private var imageOrder: [WindowSwitcherID] = []
    private var isOpen = false
    private var didLoadLauncherApps = false
    private(set) var roomCycleIndex = 0

    var filteredItems: [WindowSwitcherItem] { WindowSwitcherState.filtered(items, query: query) }

    var filteredProcessItems: [WindowSwitcherItem] { WindowSwitcherState.filtered(processItems, query: query) }

    /// Windows, Dock/menu-bar apps, and Rooms in the order shown in the picker.
    var navItems: [WindowSwitcherItem] {
        WindowSwitcherState.navigationItems(windows: filteredItems, processes: filteredProcessItems)
    }

    var navigationTargets: [WindowSwitcherTarget] {
        guard !isCreatingRoom else { return filteredItems.map { .item($0.id) } }
        return WindowSwitcherState.navigationTargets(
            windows: filteredItems,
            apps: filteredProcessItems,
            roomIDs: rooms(matching: query).map(\.id)
        )
    }

    func isSelected(_ id: WindowSwitcherID) -> Bool { selectedTarget == .item(id) }

    func selectItem(_ id: WindowSwitcherID) { selectedTarget = .item(id) }

    func selectRoom(_ id: String) {
        selectedTarget = .room(id)
        if let index = rooms(matching: query).firstIndex(where: { $0.id == id }) { roomSelection = index }
    }

    init(roomStore: RoomStore = .shared) {
        self.roomStore = roomStore
    }

    func prepare(resetSearch: Bool = true) {
        precondition(Thread.isMainThread)
        let previousSelection = resetSearch ? nil : selectedTarget
        stop()
        isOpen = true
        generation = UUID()
        if resetSearch { query = "" }
        accessibilityGranted = AXIsProcessTrusted()
        previewsGranted = CGPreflightScreenCaptureAccess()
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && !$0.isTerminated
                && WindowSwitcherState.includesApplication(
                    activationPolicy: $0.activationPolicy.rawValue,
                    bundleIdentifier: $0.bundleIdentifier)
        }
        // Keep real standalone apps, not every accessory process advertised
        // by NSWorkspace (Siri, Wi-Fi, WebKit/XPC, LoginItem helpers…). This is
        // deliberately separate from the window-owning inventory above.
        // Steam reports pid -1: pid-less apps get a synthetic negative pid and
        // are addressed through their bundle identifier at action time.
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier
                && !$0.isTerminated
        }
        let appsByPID = WindowSwitcherState.uniqueValuesByPID(runningApps.map {
            (pid: $0.processIdentifier, value: $0)
        })
        var appsByBundle: [String: NSRunningApplication] = [:]
        for app in runningApps {
            if let bundleID = app.bundleIdentifier, appsByBundle[bundleID] == nil {
                appsByBundle[bundleID] = app
            }
        }
        let listed = WindowSwitcherState.listedApplications(runningApps.map {
            .init(pid: $0.processIdentifier, activationPolicy: $0.activationPolicy.rawValue,
                  bundleIdentifier: $0.bundleIdentifier, bundlePath: $0.bundleURL?.path)
        })
        var syntheticPID: Int32 = -1
        let processSnapshots: [(pid: Int32, name: String, launchedAt: Date?, kind: WindowSwitcherItem.ItemKind, bundleID: String?)] = listed.map { identity in
            let app = identity.pid > 0 ? appsByPID[identity.pid]
                : appsByBundle[identity.bundleIdentifier ?? ""]
            let pid: Int32
            if identity.pid > 0 {
                pid = identity.pid
            } else {
                pid = syntheticPID
                syntheticPID -= 1
            }
            return (pid: pid,
                    name: app?.localizedName ?? identity.bundleIdentifier ?? "?",
                    launchedAt: app?.launchDate,
                    kind: WindowSwitcherState.processKind(activationPolicy: identity.activationPolicy) ?? .dockApp,
                    bundleID: identity.pid > 0 ? nil : identity.bundleIdentifier)
        }
        var iconsByPID: [Int32: NSImage] = [:]
        var launchedAtByPID: [Int32: Date] = [:]
        var bundleByPID: [Int32: String] = [:]
        for (app, snapshot) in zip(listed, processSnapshots) {
            let resolved = app.pid > 0 ? appsByPID[app.pid] : appsByBundle[app.bundleIdentifier ?? ""]
            if let icon = resolved?.icon { iconsByPID[snapshot.pid] = icon }
            launchedAtByPID[snapshot.pid] = snapshot.launchedAt
            if let bundleID = snapshot.bundleID { bundleByPID[snapshot.pid] = bundleID }
        }
        icons = iconsByPID
        processBundleIDs = bundleByPID
        processItems = processSnapshots.map { process in
            WindowSwitcherItem(
                id: WindowSwitcherID(pid: process.pid, windowID: 0),
                appName: process.name, title: "",
                isMinimized: false, isHidden: false, isFullScreen: false, isOnScreen: false,
                kind: process.kind)
        }
        processLaunchedAt = launchedAtByPID
        if !accessibilityGranted {
            selectedTarget = WindowSwitcherState.selection(in: navigationTargets, keeping: previousSelection)
            onReady?()
            return
        }
        isLoading = true
        let token = generation
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let snapshot = apps.map { app in
            WindowSwitcherInventory.Application(pid: app.processIdentifier,
                name: app.localizedName ?? app.bundleIdentifier ?? "", launchedAt: app.launchDate, isHidden: app.isHidden)
        }
        let work = Task.detached(priority: .userInitiated) {
            WindowSwitcherInventory.collect(apps: snapshot, frontmostPID: frontmostPID)
        }
        inventoryTask = work
        loadingTask = Task { @MainActor [weak self] in
            let result = await work.value
            guard let self, !Task.isCancelled, self.isOpen, self.generation == token else { return }
            // The AX inventory may report one window twice (role + subrole
            // fallbacks); duplicate window IDs must never trap the picker.
            self.candidates = Dictionary(result.candidates.map { ($0.item.id, $0) },
                                         uniquingKeysWith: { first, _ in first })
            self.items = result.candidates.map(\.item)
            self.focusedID = result.focused
            self.processItems = processSnapshots
                .map { process in
                    return WindowSwitcherItem(
                        id: WindowSwitcherID(pid: process.pid, windowID: 0),
                        appName: process.name, title: "",
                        isMinimized: false, isHidden: false, isFullScreen: false, isOnScreen: false,
                        kind: process.kind)
                }
            if previousSelection == nil && self.query.isEmpty {
                self.selectedTarget = WindowSwitcherState.initialSelection(
                    in: self.navigationTargets, focused: result.focused)
            } else {
                self.selectedTarget = WindowSwitcherState.selection(in: self.navigationTargets, keeping: previousSelection)
            }
            self.isLoading = false
            self.loadLauncherAppsIfNeeded()
            self.onReady?()
        }
    }

    func stop() {
        isOpen = false
        inventoryTask?.cancel()
        loadingTask?.cancel()
        previewTask?.cancel()
        closeTask?.cancel()
        closeResultTask?.cancel()
        quitTask?.cancel()
        quitResultTask?.cancel()
        closeTask = nil
        closeResultTask = nil
        quitTask = nil
        quitResultTask = nil
        closingID = nil
        quittingPID = nil
        quittingName = nil
        isForceQuitting = false
        forceQuitConfirmation = nil
        inventoryTask = nil
        loadingTask = nil
        previewTask = nil
        pendingPreviews.removeAll()
        images.removeAll()
        imageOrder.removeAll()
        attemptedPreviews.removeAll()
        completedPreviews.removeAll()
        candidates.removeAll()
        items.removeAll()
        processItems.removeAll()
        processLaunchedAt.removeAll()
        processBundleIDs.removeAll()
        icons.removeAll()
        focusedID = nil
        selectedTarget = nil
        isLoading = false
        isCreatingRoom = false
        roomName = ""
        creationLayout = .auto
        roomPicks.removeAll()
        message = ""
        messageKind = .info
        roomSelection = 0
        launcherSelection = 0
        fallbackSelection = 0
        roomActionTargetID = nil
        roomActionSelection = 0
        renamingRoomID = nil
        renameText = ""
        roomCycleIndex = 0
        launcherApps.removeAll()
        isLoadingLauncherApps = false
        didLoadLauncherApps = false
        capture = WindowThumbnailCapture()
    }

    func moveSelection(_ delta: Int, wrapping: Bool = true) {
        selectedTarget = WindowSwitcherState.moved(
            in: navigationTargets, from: selectedTarget, by: delta, wrapping: wrapping)
        syncRoomSelection()
    }

    /// Arrow-up/down in the visible grids: same column, previous/next row,
    /// crossing sections instead of walking the flat list.
    func moveSelectionVertically(_ delta: Int) {
        let sections = [
            WindowSwitcherState.GridShape(count: filteredItems.count, columns: max(1, columns)),
            WindowSwitcherState.GridShape(count: filteredProcessItems.count, columns: max(1, appColumns)),
            WindowSwitcherState.GridShape(count: rooms(matching: query).count, columns: max(1, roomColumns)),
        ]
        selectedTarget = WindowSwitcherState.movedVertically(
            in: navigationTargets, sections: sections, from: selectedTarget, by: delta)
        syncRoomSelection()
    }

    /// Keep the Rooms strip selection aligned when the keyboard lands on a room.
    private func syncRoomSelection() {
        if case .room(let id) = selectedTarget,
           let index = rooms(matching: query).firstIndex(where: { $0.id == id }) {
            roomSelection = index
        }
    }

    /// Applications/Rooms column counts for the current panel width. The
    /// spacing mirrors the view: 88pt per app tile (80 + 8), 234 per room
    /// card (224 + 10), minus the section paddings.
    func updateAuxiliaryColumns(forContentWidth width: CGFloat) {
        appColumns = max(1, Int((max(0, width - 4) + 8) / 88))
        roomColumns = max(1, Int((width + 10) / 234))
    }

    func applyCommandTabOffset(_ offset: Int) {
        selectedTarget = WindowSwitcherState.commandTabSelection(
            in: navigationTargets, focused: focusedID, offset: offset)
        syncRoomSelection()
    }

    func candidate(for id: WindowSwitcherID) -> WindowSwitcherInventory.Candidate? { candidates[id] }

    // MARK: - Room creation from the picker

    func roomPickIndex(for id: WindowSwitcherID) -> Int? {
        roomPicks.firstIndex(of: id).map { $0 + 1 }
    }

    func beginRoomCreation() {
        beginRoomCreation(named: String(format: "%@ %d", localizedString("New Room"), roomStore.rooms.count + 1))
    }

    /// Enters creation mode with a prefilled name (fallback "create room" row).
    func beginRoomCreation(named name: String) {
        precondition(Thread.isMainThread)
        guard isOpen else { return }
        isCreatingRoom = true
        if selectedID.flatMap({ candidates[$0] }) == nil, let first = filteredItems.first {
            selectItem(first.id)
        }
        roomPicks = []
        creationLayout = .auto
        roomName = name
        message = ""
        messageKind = .info
    }

    func cancelRoomCreation() {
        isCreatingRoom = false
        roomPicks = []
        roomName = ""
        creationLayout = .auto
        message = ""
        messageKind = .info
    }

    func toggleRoomPick(_ id: WindowSwitcherID) {
        guard isCreatingRoom, candidates[id] != nil else { return }
        if let index = roomPicks.firstIndex(of: id) {
            roomPicks.remove(at: index)
        } else {
            roomPicks.append(id)
        }
    }

    var canCreateRoom: Bool {
        isCreatingRoom && !roomPicks.isEmpty
            && !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func createRoom() -> Bool {
        guard canCreateRoom else { return false }
        let windows: [RoomWindow] = roomPicks.compactMap { id in
            guard let candidate = candidates[id],
                  let app = NSRunningApplication(processIdentifier: id.pid),
                  let bundleID = app.bundleIdentifier else { return nil }
            return RoomWindow(bundleID: bundleID, appName: candidate.item.appName,
                              title: candidate.item.title, windowID: id.windowID)
        }
        guard !windows.isEmpty else {
            message = localizedString("No compatible windows found. Open your project apps, then refresh.")
            messageKind = .error
            return false
        }
        let name = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let room = Room(name: name, windows: windows, layout: creationLayout)
        roomStore.upsert(room)
        isCreatingRoom = false
        roomPicks = []
        roomName = ""
        creationLayout = .auto
        message = String(format: localizedString("Room “%@” created"), name)
        messageKind = .success
        return true
    }

    // MARK: - Room switching & actions (keyboard-first)

    /// Next/previous room for the ⌥⇥ room-switch cycle.
    func roomForCycle(forward: Bool) -> Room? {
        let rooms = roomStore.rooms
        guard !rooms.isEmpty else { return nil }
        roomCycleIndex = forward
            ? (roomCycleIndex + 1) % rooms.count
            : ((roomCycleIndex - 1) % rooms.count + rooms.count) % rooms.count
        return rooms[roomCycleIndex]
    }

    var roomActionTarget: Room? {
        guard let id = roomActionTargetID else { return nil }
        return roomStore.rooms.first { $0.id == id }
    }

    func openRoomActions() {
        precondition(Thread.isMainThread)
        let rows = rooms(matching: query)
        guard !rows.isEmpty else { return }
        let selected = selectedRoomID.flatMap { id in rows.first { $0.id == id } }
        let index = selected.flatMap { room in rows.firstIndex(of: room) }
        let target = selected ?? (rows.indices.contains(roomSelection) ? rows[roomSelection] : rows[0])
        if let index { roomSelection = index }
        roomActionTargetID = target.id
        roomActionSelection = 0
        renamingRoomID = nil
        renameText = ""
    }

    func closeRoomActions() {
        roomActionTargetID = nil
        roomActionSelection = 0
        renamingRoomID = nil
        renameText = ""
    }

    func moveRoomActionSelection(_ delta: Int) {
        let count = RoomAction.allCases.count
        roomActionSelection = ((roomActionSelection + delta) % count + count) % count
    }

    func performRoomAction() {
        guard let room = roomActionTarget,
              RoomAction.allCases.indices.contains(roomActionSelection) else { return }
        performRoomAction(RoomAction.allCases[roomActionSelection], for: room)
    }

    func performRoomAction(_ action: RoomAction, for room: Room) {
        switch action {
        case .open:
            activateRoom(room)
            closeRoomActions()
        case .minimize:
            minimizeRoom(room)
            closeRoomActions()
        case .rename:
            renamingRoomID = room.id
            renameText = room.name
        case .cycleLayout:
            cycleRoomLayout(room, forward: true)
        case .duplicate:
            let copy = Room(name: localizedString("Duplicate") + " — " + room.name,
                            windows: room.windows, layout: room.layout, displayUUID: room.displayUUID)
            roomStore.upsert(copy)
            closeRoomActions()
        case .delete:
            roomStore.delete(id: room.id)
            closeRoomActions()
        }
    }

    func commitRename() {
        guard let id = renamingRoomID,
              var room = roomStore.rooms.first(where: { $0.id == id }) else {
            renamingRoomID = nil
            return
        }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        room.name = name
        roomStore.upsert(room)
        renamingRoomID = nil
        roomActionTargetID = nil
        renameText = ""
    }

    // MARK: - Fallback (rooms, apps, create)

    enum FallbackAction {
        case room(Room)
        case app(LaunchableApp)
        case createRoom(String)
    }

    func fallbackActions(query: String) -> [FallbackAction] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var actions: [FallbackAction] = rooms(matching: query).map { .room($0) }
        actions.append(contentsOf: launcherMatches.map { .app($0) })
        if !trimmed.isEmpty { actions.append(.createRoom(trimmed)) }
        return actions
    }

    func moveFallbackSelection(_ delta: Int) {
        let count = fallbackActions(query: query).count
        guard count > 0 else { return }
        fallbackSelection = ((fallbackSelection + delta) % count + count) % count
    }

    /// Performs the selected fallback action. Returns whether the picker
    /// should close (creating a room keeps it open, prefilled).
    @discardableResult
    func performSelectedFallback() -> Bool {
        let actions = fallbackActions(query: query)
        guard actions.indices.contains(fallbackSelection) else { return false }
        switch actions[fallbackSelection] {
        case .room(let room):
            activateRoom(room)
            return true
        case .app(let app):
            launch(app)
            return true
        case .createRoom(let name):
            beginRoomCreation(named: name)
            return false
        }
    }

    // MARK: - Rooms in the picker

    func rooms(matching query: String) -> [Room] {
        roomStore.rooms.filter { $0.matches(query) }
    }

    func moveRoomSelection(_ delta: Int) {
        let rows = rooms(matching: query)
        guard !rows.isEmpty else { return }
        roomSelection = ((roomSelection + delta) % rows.count + rows.count) % rows.count
        selectRoom(rows[roomSelection].id)
    }

    func selectedRoom(matching query: String) -> Room? {
        let rows = rooms(matching: query)
        if let id = selectedRoomID, let selected = rows.first(where: { $0.id == id }) { return selected }
        guard rows.indices.contains(roomSelection) else { return nil }
        return rows[roomSelection]
    }

    func setRoomLayout(_ kind: RoomLayoutKind, for room: Room) {
        var updated = room
        updated.layout = kind
        roomStore.upsert(updated)
    }

    func cycleRoomLayout(_ room: Room, forward: Bool) {
        var updated = room
        updated.layout = forward ? room.layout.next : room.layout.previous
        roomStore.upsert(updated)
    }

    func activateRoom(_ room: Room) {
        let engine = RoomEngine()
        let claimed = roomStore.claimedWindowIDs(excluding: room.id)
        HorizontalCanvasService.shared.release {
            Task { _ = await engine.activate(room, claimed: claimed) }
        }
    }

    func minimizeRoom(_ room: Room) {
        let engine = RoomEngine()
        let claimed = roomStore.claimedWindowIDs(excluding: room.id)
        HorizontalCanvasService.shared.release {
            Task { await engine.close(room, claimed: claimed) }
        }
    }

    // MARK: - Launcher fallback

    func loadLauncherAppsIfNeeded() {
        guard isOpen, !isLoading, !query.isEmpty, navItems.isEmpty,
              !didLoadLauncherApps, !isLoadingLauncherApps,
              let settings = AppRuntime.shared.settings else { return }
        didLoadLauncherApps = true
        isLoadingLauncherApps = true
        AppLauncherService().loadAppsAsync(settings: settings) { [weak self] apps in
            guard let self else { return }
            self.isLoadingLauncherApps = false
            guard self.isOpen else { return }
            let ownBundleID = Bundle.main.bundleIdentifier
            var merged = apps.filter { $0.bundleID != ownBundleID }
            // Running regular apps are always launchable, even when the
            // installed-app catalog misses them (Safari's cryptex, dev builds).
            for running in NSWorkspace.shared.runningApplications
            where running.activationPolicy == .regular && running != NSRunningApplication.current {
                guard let bundleID = running.bundleIdentifier,
                      bundleID != ownBundleID,
                      !merged.contains(where: { $0.bundleID == bundleID })
                else { continue }
                merged.append(LaunchableApp(
                    id: bundleID,
                    name: running.localizedName ?? bundleID,
                    bundleID: bundleID,
                    url: running.bundleURL ?? URL(fileURLWithPath: "/"),
                    icon: running.icon ?? NSImage(),
                    shortcut: nil,
                    snippet: nil
                ))
            }
            self.launcherApps = merged
        }
    }

    var launcherMatches: [LaunchableApp] {
        let needle = RoomText.fold(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return launcherApps.filter {
            RoomText.fold($0.name).contains(needle) || RoomText.fold($0.bundleID).contains(needle)
        }.prefix(5).map { $0 }
    }

    func moveLauncherSelection(_ delta: Int) {
        let rows = launcherMatches
        guard !rows.isEmpty else { return }
        launcherSelection = ((launcherSelection + delta) % rows.count + rows.count) % rows.count
    }

    func selectedLauncherApp() -> LaunchableApp? {
        let rows = launcherMatches
        guard rows.indices.contains(launcherSelection) else { return nil }
        return rows[launcherSelection]
    }

    func launch(_ app: LaunchableApp) {
        guard let settings = AppRuntime.shared.settings else { return }
        _ = AppLauncherService().launch(app, settings: settings)
    }

    func closeWindow(_ id: WindowSwitcherID) {
        precondition(Thread.isMainThread)
        guard isOpen, closingID == nil, quittingPID == nil, let candidate = candidates[id] else { return }
        closingID = id
        message = ""
        messageKind = .info
        let token = generation
        let work = Task.detached(priority: .userInitiated) { WindowSwitcherInventory.close(candidate) }
        closeTask = work
        closeResultTask = Task { @MainActor [weak self] in
            let result = await work.value
            guard let self, !Task.isCancelled, self.isOpen, self.generation == token else { return }
            self.closingID = nil
            self.closeTask = nil
            self.closeResultTask = nil
            switch result {
            case .closed:
                let next = WindowSwitcherState.selectionAfterClosing(
                    id, in: self.navigationTargets, selected: self.selectedTarget)
                self.items.removeAll { $0.id == id }
                self.candidates.removeValue(forKey: id)
                self.images.removeValue(forKey: id)
                self.completedPreviews.remove(id)
                self.attemptedPreviews.remove(id)
                self.pendingPreviews.removeAll { $0 == id }
                self.imageOrder.removeAll { $0 == id }
                self.selectedTarget = next
            case .pending:
                self.message = localizedString("The window has not closed yet. Open it to check for a save dialog, or refresh the list.")
                self.messageKind = .error
            case .unavailable, .failed:
                self.message = localizedString("This window cannot be closed right now. Open it or refresh the list.")
                self.messageKind = .error
            case .cancelled: break
            }
        }
    }

    /// Quits the app that owns the selected window, not just that window.
    /// The request is graceful so the app still owns its save dialogs.
    func quitApp(_ id: WindowSwitcherID) {
        precondition(Thread.isMainThread)
        guard isOpen, closingID == nil, quittingPID == nil, let candidate = candidates[id] else { return }
        beginQuit(pid: id.pid, name: candidate.item.appName, launchedAt: candidate.launchedAt)
    }

    /// Quits a windowless process listed in the picker's dedicated sections.
    func quitProcess(_ id: WindowSwitcherID) {
        precondition(Thread.isMainThread)
        guard isOpen, closingID == nil, quittingPID == nil,
              let item = processItems.first(where: { $0.id == id }),
              let launchedAt = processLaunchedAt[id.pid] else { return }
        beginQuit(pid: id.pid, name: item.appName, launchedAt: launchedAt)
    }

    func requestForceQuit(_ id: WindowSwitcherID) {
        precondition(Thread.isMainThread)
        guard isOpen, closingID == nil, quittingPID == nil else { return }
        if let candidate = candidates[id] {
            forceQuitConfirmation = ForceQuitConfirmation(
                id: id, appName: candidate.item.appName, launchedAt: candidate.launchedAt)
        } else if let item = processItems.first(where: { $0.id == id }),
                  let launchedAt = processLaunchedAt[id.pid] {
            forceQuitConfirmation = ForceQuitConfirmation(id: id, appName: item.appName, launchedAt: launchedAt)
        }
    }

    func cancelForceQuit() { forceQuitConfirmation = nil }

    func confirmForceQuit() {
        guard let confirmation = forceQuitConfirmation else { return }
        forceQuitConfirmation = nil
        beginQuit(pid: confirmation.id.pid, name: confirmation.appName,
                  launchedAt: confirmation.launchedAt, force: true)
    }

    /// Brings a windowless process forward: regular apps activate like a Dock
    /// click, menu-bar apps reveal their panel when they support it. Pid-less
    /// apps (Steam) resolve through their bundle identifier.
    func activateProcess(_ id: WindowSwitcherID) {
        precondition(Thread.isMainThread)
        guard isOpen, processItems.contains(where: { $0.id == id }) else { return }
        if id.pid > 0 {
            guard let app = NSRunningApplication(processIdentifier: id.pid), !app.isTerminated else { return }
            _ = app.unhide()
            _ = app.activate(options: [])
            return
        }
        guard let bundleID = processBundleIDs[id.pid],
              let app = NSWorkspace.shared.runningApplications.first(where: {
                  $0.bundleIdentifier == bundleID && !$0.isTerminated
              }) else { return }
        _ = app.unhide()
        if !app.activate(options: []), let url = app.bundleURL {
            NSWorkspace.shared.open(url)
        }
    }

    private func beginQuit(pid: Int32, name: String, launchedAt: Date?, force: Bool = false) {
        quittingPID = pid
        quittingName = name
        isForceQuitting = force
        message = ""
        messageKind = .info
        let token = generation
        // Pid-less apps (Steam reports -1) are addressed by bundle identity.
        let bundleID = pid < 0 ? processBundleIDs[pid] : nil
        let work = Task.detached(priority: .userInitiated) {
            if let bundleID {
                return WindowSwitcherInventory.quitInstance(
                    bundleIdentifier: bundleID, launchedAt: launchedAt, force: force)
            }
            return WindowSwitcherInventory.quit(pid: pid, launchedAt: launchedAt, force: force)
        }
        quitTask = work
        quitResultTask = Task { @MainActor [weak self] in
            let result = await work.value
            guard let self, !Task.isCancelled, self.isOpen, self.generation == token else { return }
            self.quittingPID = nil
            self.quittingName = nil
            self.isForceQuitting = false
            self.quitTask = nil
            self.quitResultTask = nil
            switch result {
            case .quit:
                let removed = self.items.filter { $0.id.pid == pid }.map(\.id)
                let next = WindowSwitcherState.selectionAfterQuitting(
                    pid: pid, in: self.navigationTargets, selected: self.selectedTarget)
                self.items.removeAll { $0.id.pid == pid }
                self.processItems.removeAll { $0.id.pid == pid }
                self.processLaunchedAt.removeValue(forKey: pid)
                for window in removed {
                    self.candidates.removeValue(forKey: window)
                    self.images.removeValue(forKey: window)
                    self.completedPreviews.remove(window)
                    self.attemptedPreviews.remove(window)
                    self.pendingPreviews.removeAll { $0 == window }
                    self.imageOrder.removeAll { $0 == window }
                }
                self.icons.removeValue(forKey: pid)
                if self.focusedID?.pid == pid { self.focusedID = nil }
                self.selectedTarget = next
            case .pending:
                self.message = localizedString("The app has not quit yet. A save dialog may be waiting, or it refused to quit.")
                self.messageKind = .error
            case .failed:
                self.message = localizedString("This app cannot be quit right now. Try again or quit it from the app.")
                self.messageKind = .error
            case .cancelled: break
            }
        }
    }

    /// Lazy grid cells enqueue requests; one screenshot at a time, bounded RAM.
    func requestPreview(_ id: WindowSwitcherID) {
        guard isOpen, previewsGranted, candidates[id] != nil,
              !attemptedPreviews.contains(id), !pendingPreviews.contains(id) else { return }
        pendingPreviews.append(id)
        guard previewTask == nil else { return }
        let token = generation
        let capture = capture
        previewTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isOpen, self.generation == token, !self.pendingPreviews.isEmpty {
                let id = self.pendingPreviews.removeFirst()
                guard self.filteredItems.contains(where: { $0.id == id }) else { continue }
                self.attemptedPreviews.insert(id)
                let image = await capture.image(for: id)
                guard !Task.isCancelled, self.isOpen, self.generation == token else { return }
                guard self.candidates[id] != nil else { continue }
                self.completedPreviews.insert(id)
                if let image {
                    self.images[id] = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                    self.imageOrder.append(id)
                    if self.imageOrder.count > 48 {
                        let oldest = self.imageOrder.removeFirst()
                        self.images.removeValue(forKey: oldest)
                        self.attemptedPreviews.remove(oldest)
                        self.completedPreviews.remove(oldest)
                    }
                }
            }
            if self.generation == token { self.previewTask = nil }
        }
    }

    func requestPreviews() {
        _ = CGRequestScreenCaptureAccess()
        if CGPreflightScreenCaptureAccess() {
            if isOpen { prepare(resetSearch: false) }
        } else {
            Self.openPrivacySettings("Privacy_ScreenCapture")
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        Self.openPrivacySettings("Privacy_Accessibility")
    }

    private static func openPrivacySettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?" + pane) {
            NSWorkspace.shared.open(url)
        }
    }
}
