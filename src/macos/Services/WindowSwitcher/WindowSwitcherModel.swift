import AppKit
import ApplicationServices
import Combine

/// Tone of the picker's status message.
enum MessageKind {
    case info
    case success
    case error
}

/// UI state lives on main, AX inventory and capture run off the event tap.
final class WindowSwitcherModel: ObservableObject {
    @Published private(set) var items: [WindowSwitcherItem] = []
    @Published var query = "" {
        didSet {
            selectedID = WindowSwitcherState.selection(in: filteredItems, keeping: selectedID)
            roomSelection = 0
            launcherSelection = 0
            loadLauncherAppsIfNeeded()
        }
    }
    @Published var selectedID: WindowSwitcherID?
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
    var onReady: (() -> Void)?
    var columns = 3
    var cardHeight: CGFloat = 210
    var isBusy: Bool { closingID != nil || quittingPID != nil }
    private(set) var icons: [pid_t: NSImage] = [:]
    let roomStore: RoomStore
    private var candidates: [WindowSwitcherID: WindowSwitcherInventory.Candidate] = [:]
    private var focusedID: WindowSwitcherID?
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

    var filteredItems: [WindowSwitcherItem] { WindowSwitcherState.filtered(items, query: query) }

    init(roomStore: RoomStore = .shared) {
        self.roomStore = roomStore
    }

    func prepare(resetSearch: Bool = true) {
        precondition(Thread.isMainThread)
        let previousSelection = resetSearch ? nil : selectedID
        stop()
        isOpen = true
        generation = UUID()
        if resetSearch { query = "" }
        accessibilityGranted = AXIsProcessTrusted()
        previewsGranted = CGPreflightScreenCaptureAccess()
        guard accessibilityGranted else { return }
        isLoading = true
        let token = generation
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && !$0.isTerminated
                && WindowSwitcherState.includesApplication(
                    activationPolicy: $0.activationPolicy.rawValue,
                    bundleIdentifier: $0.bundleIdentifier)
        }
        icons = Dictionary(uniqueKeysWithValues: apps.compactMap { app in
            app.icon.map { (app.processIdentifier, $0) }
        })
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
            self.candidates = Dictionary(uniqueKeysWithValues: result.candidates.map { ($0.item.id, $0) })
            self.items = result.candidates.map(\.item)
            self.focusedID = result.focused
            self.selectedID = previousSelection == nil && self.query.isEmpty
                ? WindowSwitcherState.initialSelection(in: self.items, focused: result.focused)
                : WindowSwitcherState.selection(in: self.filteredItems, keeping: previousSelection)
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
        icons.removeAll()
        focusedID = nil
        selectedID = nil
        isLoading = false
        isCreatingRoom = false
        roomName = ""
        creationLayout = .auto
        roomPicks.removeAll()
        message = ""
        messageKind = .info
        roomSelection = 0
        launcherSelection = 0
        launcherApps.removeAll()
        isLoadingLauncherApps = false
        didLoadLauncherApps = false
        capture = WindowThumbnailCapture()
    }

    func moveSelection(_ delta: Int, wrapping: Bool = true) {
        selectedID = WindowSwitcherState.moved(in: filteredItems, from: selectedID, by: delta, wrapping: wrapping)
    }

    func applyCommandTabOffset(_ offset: Int) {
        if !query.isEmpty {
            selectedID = filteredItems.first?.id
        } else {
            selectedID = WindowSwitcherState.commandTabSelection(in: filteredItems, focused: focusedID, offset: offset)
        }
    }

    func candidate(for id: WindowSwitcherID) -> WindowSwitcherInventory.Candidate? { candidates[id] }

    // MARK: - Room creation from the picker

    func roomPickIndex(for id: WindowSwitcherID) -> Int? {
        roomPicks.firstIndex(of: id).map { $0 + 1 }
    }

    func beginRoomCreation() {
        precondition(Thread.isMainThread)
        guard isOpen else { return }
        isCreatingRoom = true
        roomPicks = []
        creationLayout = .auto
        roomName = String(format: "%@ %d", localizedString("New Room"), roomStore.rooms.count + 1)
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
        guard isCreatingRoom else { return }
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

    // MARK: - Rooms in the picker

    func rooms(matching query: String) -> [Room] {
        roomStore.rooms.filter { $0.matches(query) }
    }

    func moveRoomSelection(_ delta: Int) {
        let rows = rooms(matching: query)
        guard !rows.isEmpty else { return }
        roomSelection = ((roomSelection + delta) % rows.count + rows.count) % rows.count
    }

    func selectedRoom(matching query: String) -> Room? {
        let rows = rooms(matching: query)
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
        guard isOpen, !isLoading, !query.isEmpty, filteredItems.isEmpty,
              !didLoadLauncherApps, !isLoadingLauncherApps,
              let settings = AppRuntime.shared.settings else { return }
        didLoadLauncherApps = true
        isLoadingLauncherApps = true
        AppLauncherService().loadAppsAsync(settings: settings) { [weak self] apps in
            guard let self else { return }
            self.isLoadingLauncherApps = false
            guard self.isOpen else { return }
            let ownBundleID = Bundle.main.bundleIdentifier
            self.launcherApps = apps.filter { $0.bundleID != ownBundleID }
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
                let next = WindowSwitcherState.selectionAfterClosing(id, in: self.filteredItems, selected: self.selectedID)
                self.items.removeAll { $0.id == id }
                self.candidates.removeValue(forKey: id)
                self.images.removeValue(forKey: id)
                self.completedPreviews.remove(id)
                self.attemptedPreviews.remove(id)
                self.pendingPreviews.removeAll { $0 == id }
                self.imageOrder.removeAll { $0 == id }
                self.selectedID = next
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
        let appName = candidate.item.appName
        let pid = id.pid
        let launchedAt = candidate.launchedAt
        quittingPID = pid
        quittingName = appName
        message = ""
        messageKind = .info
        let token = generation
        let work = Task.detached(priority: .userInitiated) {
            WindowSwitcherInventory.quit(pid: pid, launchedAt: launchedAt)
        }
        quitTask = work
        quitResultTask = Task { @MainActor [weak self] in
            let result = await work.value
            guard let self, !Task.isCancelled, self.isOpen, self.generation == token else { return }
            self.quittingPID = nil
            self.quittingName = nil
            self.quitTask = nil
            self.quitResultTask = nil
            switch result {
            case .quit:
                let removed = self.items.filter { $0.id.pid == pid }.map(\.id)
                let next = WindowSwitcherState.selectionAfterQuitting(
                    pid: pid, in: self.filteredItems, selected: self.selectedID)
                self.items.removeAll { $0.id.pid == pid }
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
                self.selectedID = next
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
        guard isOpen, previewsGranted, !attemptedPreviews.contains(id), !pendingPreviews.contains(id) else { return }
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
