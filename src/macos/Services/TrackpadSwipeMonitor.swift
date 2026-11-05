import AppKit
import Foundation

/// Pure detection rules, shared by the live monitor and unit checks.
struct TrackpadSwipeDetector {
    var requiredFingers = 3
    var minimumTravel: Float = 0.10
    var maximumDuration: TimeInterval = 0.8
    var cooldown: TimeInterval = 0.6

    private var startedAt: TimeInterval?
    private var startY: Float = 0
    private var lastFire: TimeInterval = -.infinity
    private var armed = true

    /// Returns true exactly once per upward gesture. `y` is the first contact
    /// position in normalized trackpad coordinates (0 = bottom, 1 = top).
    mutating func update(fingers: Int, y: Float, time: TimeInterval) -> Bool {
        guard fingers >= requiredFingers else {
            startedAt = nil
            armed = true
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
        if y - startY >= minimumTravel, time - lastFire >= cooldown {
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
/// framework (the same mechanism as Mission Control itself). A four-finger
/// upward swipe can then open Exposé PK. The macOS gesture must be released
/// separately, otherwise both views react to the same physical gesture.
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
    private typealias CreateList = @convention(c) () -> CFArray?
    private typealias Register = @convention(c) (UnsafeMutableRawPointer, ContactCallback?) -> Void
    private typealias Start = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias Stop = @convention(c) (UnsafeMutableRawPointer) -> Void

    private var handle: UnsafeMutableRawPointer?
    private var devices: [UnsafeMutableRawPointer] = []
    private var detector = TrackpadSwipeDetector()
    private var register: Register?
    private var stopFunction: Stop?
    private var started = false
    private let lock = NSLock()

    var isEnabled: () -> Bool = { true }
    var onSwipeUp: () -> Void = {}

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
              let startSym = dlsym(handle, "MTDeviceStart") else { return }
        let create = unsafeBitCast(createSym, to: CreateList.self)
        register = unsafeBitCast(registerSym, to: Register.self)
        stopFunction = dlsym(handle, "MTDeviceStop").map { unsafeBitCast($0, to: Stop.self) }
        let devices = (create() as? [AnyObject])?.compactMap { $0 as? UnsafeMutableRawPointer } ?? []
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
            register?(device, nil)
        }
        devices.removeAll()
        detector.reset()
        started = false
    }

    /// Byte offset of the first contact's normalized Y in the C layout
    /// described by `Contact`. Reading the raw pointer avoids exporting a
    /// Swift struct through a C callback (not ObjC-representable).
    static let contactPositionYOffset = MemoryLayout<Contact>.offset(of: \.normalized.position.y) ?? 36

    fileprivate func receive(fingers: Int, y: Float, timestamp: TimeInterval) {
        guard isEnabled() else { detector.reset(); return }
        lock.lock()
        let fired = detector.update(fingers: fingers, y: y, time: timestamp)
        lock.unlock()
        guard fired else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isEnabled() else { return }
            self.onSwipeUp()
        }
    }
}

private func trackpadCallback(_ device: Int32, _ contacts: UnsafeRawPointer?,
                              _ count: Int32, _ timestamp: Double, _ frame: Int32) {
    guard let contacts, count > 0 else { return }
    let y = contacts.load(fromByteOffset: TrackpadSwipeMonitor.contactPositionYOffset, as: Float.self)
    TrackpadSwipeMonitor.shared.receive(fingers: Int(count), y: y, timestamp: timestamp)
}
