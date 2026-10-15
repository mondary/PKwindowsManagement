import AppKit
import ApplicationServices
import Combine

/// UI state lives on main, AX inventory and capture run off the event tap.
final class WindowSwitcherModel: ObservableObject {
    @Published private(set) var items: [WindowSwitcherItem] = []
    @Published var query = "" {
        didSet { selectedID = WindowSwitcherState.selection(in: filteredItems, keeping: selectedID) }
    }
    @Published var selectedID: WindowSwitcherID?
    @Published private(set) var isLoading = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var previewsGranted = false
    @Published private(set) var images: [WindowSwitcherID: NSImage] = [:]
    @Published private(set) var completedPreviews = Set<WindowSwitcherID>()
    @Published private(set) var generation = UUID()
    @Published var message = ""
    @Published private(set) var closingID: WindowSwitcherID?
    var columns = 3
    private(set) var icons: [pid_t: NSImage] = [:]
    private var candidates: [WindowSwitcherID: WindowSwitcherInventory.Candidate] = [:]
    private var inventoryTask: Task<WindowSwitcherInventory.Snapshot, Never>?
    private var loadingTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var closeTask: Task<WindowCloseRequest.Result, Never>?
    private var closeResultTask: Task<Void, Never>?
    private var capture = WindowThumbnailCapture()
    private var pendingPreviews: [WindowSwitcherID] = []
    private var attemptedPreviews = Set<WindowSwitcherID>()
    private var imageOrder: [WindowSwitcherID] = []
    private var isOpen = false

    var filteredItems: [WindowSwitcherItem] { WindowSwitcherState.filtered(items, query: query) }

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
                && ($0.activationPolicy == .regular || $0.activationPolicy == .accessory)
                && !$0.isTerminated
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
            self.selectedID = previousSelection == nil && self.query.isEmpty
                ? WindowSwitcherState.initialSelection(in: self.items, focused: result.focused)
                : WindowSwitcherState.selection(in: self.filteredItems, keeping: previousSelection)
            self.isLoading = false
        }
    }

    func stop() {
        isOpen = false
        inventoryTask?.cancel()
        loadingTask?.cancel()
        previewTask?.cancel()
        closeTask?.cancel()
        closeResultTask?.cancel()
        closeTask = nil
        closeResultTask = nil
        closingID = nil
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
        selectedID = nil
        isLoading = false
        capture = WindowThumbnailCapture()
    }

    func moveSelection(_ delta: Int, wrapping: Bool = true) {
        selectedID = WindowSwitcherState.moved(in: filteredItems, from: selectedID, by: delta, wrapping: wrapping)
    }

    func candidate(for id: WindowSwitcherID) -> WindowSwitcherInventory.Candidate? { candidates[id] }

    func closeWindow(_ id: WindowSwitcherID) {
        precondition(Thread.isMainThread)
        guard isOpen, closingID == nil, let candidate = candidates[id] else { return }
        closingID = id
        message = ""
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
            case .unavailable, .failed:
                self.message = localizedString("This window cannot be closed right now. Open it or refresh the list.")
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
