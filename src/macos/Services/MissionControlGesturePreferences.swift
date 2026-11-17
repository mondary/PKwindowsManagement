import Foundation
import CoreFoundation

/// This changes persisted preferences only, after confirmation in Settings.
/// It neither consumes native events nor restarts Dock/System Settings.
/// macOS may keep the previous gesture mapping until the next login.
struct MissionControlGesturePreferences {
    static let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    ]

    enum Status: Equatable {
        case conflict
        case released
        case unknown
    }

    struct Change: Equatable {
        let domain: String
        let key: String
        let value: Int
    }

    enum SaveError: Error {
        case saveFailed
        case rollbackFailed
    }

    struct Store {
        var read: (_ domain: String, _ key: String) -> Int?
        var write: (_ domain: String, _ key: String, _ value: Int?) -> Void
        var synchronize: (_ domain: String) -> Bool

        static let live = Store(
            read: { domain, key in
                let value = CFPreferencesCopyValue(
                    key as CFString, domain as CFString,
                    kCFPreferencesCurrentUser, kCFPreferencesAnyHost
                )
                return (value as? NSNumber)?.intValue
            },
            write: { domain, key, value in
                let property: CFPropertyList? = value.map { NSNumber(value: $0) }
                CFPreferencesSetValue(
                    key as CFString, property, domain as CFString,
                    kCFPreferencesCurrentUser, kCFPreferencesAnyHost
                )
            },
            synchronize: { domain in
                CFPreferencesSynchronize(
                    domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
                )
            }
        )
    }

    private let store: Store

    init(store: Store = .live) {
        self.store = store
    }

    static func normalizedCount(_ count: Int) -> Int { count == 3 ? 3 : 4 }

    static func key(for fingers: Int) -> String {
        fingers == 3 ? "TrackpadThreeFingerVertSwipeGesture" : "TrackpadFourFingerVertSwipeGesture"
    }

    /// Both built-in and Bluetooth trackpads must agree. An absent key is
    /// unknown, NOT proof that the native gesture is disabled.
    func status(pkFingers: Int) -> Status {
        let key = Self.key(for: Self.normalizedCount(pkFingers))
        let values = Self.domains.map { store.read($0, key) }
        if values.contains(where: { $0 == 2 }) { return .conflict }
        if values.allSatisfy({ $0 == 0 }) { return .released }
        return .unknown
    }

    /// Mission Control on the other count (2); no native vertical gesture on
    /// PK's count (0). Horizontal Space switching and keyboard shortcuts are
    /// deliberately absent from this plan.
    static func plan(pkFingers: Int) -> [Change] {
        let pk = normalizedCount(pkFingers)
        let native = pk == 4 ? 3 : 4
        return domains.flatMap { domain in
            [
                Change(domain: domain, key: key(for: pk), value: 0),
                Change(domain: domain, key: key(for: native), value: 2)
            ]
        }
    }

    /// Called only by the confirmed button action, never at startup, on a
    /// picker change, or while merely reading status. Restore missing keys as
    /// missing (not zero) if saving or readback fails.
    func apply(pkFingers: Int) throws {
        let changes = Self.plan(pkFingers: pkFingers)
        let previous = changes.map { store.read($0.domain, $0.key) }
        for change in changes { store.write(change.domain, change.key, change.value) }
        let synchronized = Self.domains.map { store.synchronize($0) }
        let saved = synchronized.allSatisfy { $0 }
            && changes.allSatisfy { store.read($0.domain, $0.key) == $0.value }
        guard saved else {
            for (change, value) in zip(changes, previous) {
                store.write(change.domain, change.key, value)
            }
            let rollback = Self.domains.map { store.synchronize($0) }
            let restored = rollback.allSatisfy { $0 }
                && zip(changes, previous).allSatisfy { change, value in
                    store.read(change.domain, change.key) == value
                }
            throw restored ? SaveError.saveFailed : SaveError.rollbackFailed
        }
    }
}
