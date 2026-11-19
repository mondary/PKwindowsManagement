import AppKit
import Foundation

/// Pure detection rules, shared by the live monitor and unit checks.
struct TrackpadSwipeDetector {
    enum Direction { case up, down }
    private(set) var direction: Direction
    /// Exact contact count that fires the gesture: 3 or 4, never "or more" —
    /// the other count keeps serving the system (Mission Control and friends).
    var requiredFingers = 4
    var minimumTravel: Float = 0.10
    var maximumDuration: TimeInterval = 0.8
    // A new touch can open again immediately after Escape or cancellation.
    var cooldown: TimeInterval = 0

    private var startedAt: TimeInterval?
    private var startY: Float = 0
    private var lastFire: TimeInterval = -.infinity
    private var armed = true

    init(direction: Direction = .up) { self.direction = direction }

    /// Reversing intent is a new gesture, not another opening bounce: a quick
    /// down-cancel must not wait for the up gesture's 600 ms cooldown.
    mutating func setDirection(_ direction: Direction) {
        guard self.direction != direction else { return }
        self.direction = direction
        lastFire = -.infinity
        reset()
    }

    /// Returns true exactly once per configured direction. `y` is the first contact
    /// position in normalized trackpad coordinates (0 = bottom, 1 = top).
    mutating func update(fingers: Int, y: Float, time: TimeInterval) -> Bool {
        guard fingers == requiredFingers else {
            startedAt = nil
            if fingers == 0 { armed = true }
            return false
        }
        guard armed, y.isFinite, (0...1).contains(y) else { return false }
        if startedAt == nil {
            startedAt = time
            startY = y
            return false
        }
        guard let start = startedAt else { return false }
        if time - start > maximumDuration {
            startedAt = nil
            return false
        }
        let travel = direction == .up ? y - startY : startY - y
        if travel >= minimumTravel, time - lastFire >= cooldown {
            lastFire = time
            armed = false
            startedAt = nil
            return true
        }
        return false
    }

    mutating func reset() {
        startedAt = nil
        armed = true
    }
}

/// Reads raw trackpad contacts through Apple's private MultitouchSupport
/// framework (the same mechanism as Mission Control itself). A three- or
/// four-finger upward swipe can open Exposé PK. Set the macOS gesture to the
/// other count separately, otherwise both views can react to the same swipe.
final class TrackpadSwipeMonitor {
    static let shared = TrackpadSwipeMonitor()

    /// Contact layout exposed by MultitouchSupport. Only the first contact's
    /// normalized position is read; trailing fields may change between macOS
    /// releases without affecting that offset.
    struct Point { var x: Float; var y: Float }
    struct Vector { var position: Point; var velocity: Point }
    struct Contact {
        var frame: Int32
        var timestamp: Double
        var identifier: Int32
        var state: Int32
        var field1: Int32
        var field2: Int32
        var normalized: Vector
        var size: Float
        var zero1: Int32
        var angle: Float
        var majorAxis: Float
        var minorAxis: Float
        var absolute: Vector
        var zero2: Int32
        var button: Int32
    }

    private typealias ContactCallback = @convention(c)
        (Int32, UnsafeRawPointer?, Int32, Double, Int32) -> Void
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    private typealias Register = @convention(c) (UnsafeMutableRawPointer, ContactCallback?) -> Void
    private typealias Start = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias Stop = @convention(c) (UnsafeMutableRawPointer) -> Void

    private var handle: UnsafeMutableRawPointer?
    // Keep the owning array alive for as long as its unretained device pointers.
    private var deviceList: CFArray?
    private var devices: [UnsafeMutableRawPointer] = []
    private var detector = TrackpadSwipeDetector()
    private var gestureDirection: TrackpadSwipeDetector.Direction?
    private var lastFrameAt: TimeInterval?
    private var scrollGate = TrackpadScrollGate()
    private var register: Register?
    private var unregister: Register?
    private var stopFunction: Stop?
    private var started = false
    private let lock = NSLock()

    var isEnabled: () -> Bool = { true }
    var requiredFingers: () -> Int = { 4 }
    var onSwipeUp: () -> Void = {}
    var onSwipeDown: () -> Void = {}
    var isExposePresented: () -> Bool = { false }

    var isRunning: Bool { started }

    func start() {
        guard !started else { return }
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else {
            NSLog("PKwindowsManagement: MultitouchSupport unavailable (%@)", String(cString: dlerror()))
            return
        }
        self.handle = handle
        guard let createSym = dlsym(handle, "MTDeviceCreateList"),
              let registerSym = dlsym(handle, "MTRegisterContactFrameCallback"),
              let unregisterSym = dlsym(handle, "MTUnregisterContactFrameCallback"),
              let startSym = dlsym(handle, "MTDeviceStart") else { return }
        let create = unsafeBitCast(createSym, to: CreateList.self)
        register = unsafeBitCast(registerSym, to: Register.self)
        unregister = unsafeBitCast(unregisterSym, to: Register.self)
        stopFunction = dlsym(handle, "MTDeviceStop").map { unsafeBitCast($0, to: Stop.self) }
        deviceList = create()?.takeRetainedValue()
        let devices = deviceList.map(Self.devicePointers(in:)) ?? []
        self.devices = devices
        for device in devices {
            register?(device, trackpadCallback)
            unsafeBitCast(startSym, to: Start.self)(device, 0)
        }
        started = !devices.isEmpty
        NSLog("PKwindowsManagement: trackpad swipe monitor started on %d device(s)", devices.count)
    }

    func stop() {
        for device in devices {
            stopFunction?(device)
            unregister?(device, trackpadCallback)
        }
        devices.removeAll()
        deviceList = nil
        lock.lock()
        detector.reset()
        gestureDirection = nil
        lastFrameAt = nil
        scrollGate.configure(enabled: false, requiredFingers: 4)
        lock.unlock()
        started = false
    }

    /// Byte offset of the first contact's normalized Y in the C layout
    /// described by `Contact`. Reading the raw pointer avoids exporting a
    /// Swift struct through a C callback (not ObjC-representable).
    static let contactPositionYOffset = MemoryLayout<Contact>.offset(of: \.normalized.position.y) ?? 36

    /// CFArray stores MTDeviceRef values, not boxed Swift pointer objects.
    /// Bridging to [AnyObject] then casting to UnsafeMutableRawPointer drops
    /// every device, leaving the old monitor silently inactive.
    static func devicePointers(in list: CFArray) -> [UnsafeMutableRawPointer] {
        (0..<CFArrayGetCount(list)).compactMap { index in
            CFArrayGetValueAtIndex(list, index).map { UnsafeMutableRawPointer(mutating: $0) }
        }
    }

    /// Empty frames must reach the detector to rearm after ALL fingers lift.
    static func contactY(from contacts: UnsafeRawPointer?, count: Int32) -> Float {
        guard let contacts, count > 0 else { return 0 }
        return contacts.load(fromByteOffset: contactPositionYOffset, as: Float.self)
    }

    /// Published settings are copied here on main; raw callbacks never read
    /// AppSettings. The event tap can consult this tiny locked state at once.
    func configureScrollSuppression(enabled: Bool, requiredFingers: Int) {
        lock.lock()
        scrollGate.configure(enabled: enabled, requiredFingers: requiredFingers)
        lock.unlock()
    }

    func shouldSuppressScroll(isContinuous: Bool, isMomentum: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return scrollGate.shouldSuppress(
            isContinuous: isContinuous, isMomentum: isMomentum,
            time: ProcessInfo.processInfo.systemUptime
        )
    }

    func receive(fingers: Int, y: Float, timestamp: TimeInterval) {
        // Claim raw contacts synchronously BEFORE dispatching detection to
        // main. Otherwise the first wheel events can reach the page first.
        lock.lock()
        scrollGate.updateContacts(fingers: fingers, time: ProcessInfo.processInfo.systemUptime)
        lock.unlock()
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.processContacts(fingers: fingers, y: y, timestamp: timestamp)
            }
            return
        }
        processContacts(fingers: fingers, y: y, timestamp: timestamp)
    }

    private func processContacts(fingers: Int, y: Float, timestamp: TimeInterval) {
        // Observable preferences and activation callbacks stay on main.
        lock.lock()
        guard isEnabled() else {
            detector.reset()
            gestureDirection = nil
            lastFrameAt = nil
            lock.unlock()
            return
        }
        let required = requiredFingers() == 3 ? 3 : 4
        if detector.requiredFingers != required {
            detector.reset()
            detector.requiredFingers = required
            gestureDirection = nil
        }
        // Driver/device interruption can omit the final empty frame. Rearm
        // after a gap beyond any valid swipe rather than keep stale intent.
        if let lastFrameAt, timestamp - lastFrameAt > detector.maximumDuration {
            detector.reset()
            gestureDirection = nil
        }
        lastFrameAt = timestamp
        if fingers == 0 { gestureDirection = nil }
        if gestureDirection == nil, fingers == required {
            let direction: TrackpadSwipeDetector.Direction = isExposePresented() ? .down : .up
            gestureDirection = direction
            detector.setDirection(direction)
        }
        // Lock intent for the whole touch: opening Exposé mid-swipe must not
        // reinterpret a small reverse movement as an immediate cancellation.
        let direction = gestureDirection
        let fired = detector.update(fingers: fingers, y: y, time: timestamp)
        lock.unlock()
        guard fired, let direction else { return }
        // Already on main. A second async hop lets later contact frames
        // infer their direction from stale presentation state.
        switch direction {
        case .up:
            guard !isExposePresented() else { return }
            onSwipeUp()
        case .down:
            guard isExposePresented() else { return }
            onSwipeDown()
        }
    }
}

private func trackpadCallback(_ device: Int32, _ contacts: UnsafeRawPointer?,
                              _ count: Int32, _ timestamp: Double, _ frame: Int32) {
    let y = TrackpadSwipeMonitor.contactY(from: contacts, count: count)
    TrackpadSwipeMonitor.shared.receive(fingers: Int(count), y: y, timestamp: timestamp)
}
