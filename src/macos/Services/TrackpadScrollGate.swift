import Foundation

/// Pure scroll arbitration. Claim the configured multi-finger touch BEFORE
/// travel reaches the Exposé threshold, not after the page has already moved.
/// A fresh two-finger touch always releases the claim and its momentum tail.
struct TrackpadScrollGate {
    private(set) var enabled = false
    private(set) var requiredFingers = 4

    var contactFreshness: TimeInterval = 0.25
    var releaseGrace: TimeInterval = 0.06
    var momentumSilence: TimeInterval = 0.18
    var maximumTailDuration: TimeInterval = 3

    private var fingers = 0
    private var lastContactsAt: TimeInterval = -.infinity
    private var ownsTouch = false
    private var exceededRequiredCount = false
    private var releasedAt: TimeInterval?
    private var lastSuppressedAt: TimeInterval = -.infinity

    mutating func configure(enabled: Bool, requiredFingers: Int) {
        let count = requiredFingers == 3 ? 3 : 4
        guard self.enabled != enabled || self.requiredFingers != count else { return }
        self.enabled = enabled
        self.requiredFingers = count
        reset()
    }

    mutating func updateContacts(fingers next: Int, time: TimeInterval) {
        guard enabled, next >= 0, time.isFinite else { reset(); return }
        guard time >= lastContactsAt else { return }
        if time - lastContactsAt > contactFreshness { reset() }
        // A new physical touch cancels old inertia immediately. Merely lifting
        // fingers one by one does not give the claimed gesture back to apps.
        if next > 0 && fingers == 0 {
            ownsTouch = false
            exceededRequiredCount = false
            releasedAt = nil
            lastSuppressedAt = -.infinity
        }
        if next > requiredFingers {
            // PK on three fingers must not steal a native four-finger
            // gesture that briefly passed through three during placement.
            exceededRequiredCount = true
            ownsTouch = false
            releasedAt = nil
        }
        if next == requiredFingers && !exceededRequiredCount {
            ownsTouch = true
            releasedAt = nil
        } else if next == 0 && fingers > 0 {
            releasedAt = ownsTouch ? time : nil
            if ownsTouch { lastSuppressedAt = time }
            ownsTouch = false
        }
        fingers = next
        lastContactsAt = time
    }

    mutating func shouldSuppress(isContinuous: Bool, isMomentum: Bool, time: TimeInterval) -> Bool {
        // Never intercept a discrete mouse wheel.
        guard enabled, isContinuous, time.isFinite else { return false }
        if fingers > 0 {
            guard time >= lastContactsAt, time - lastContactsAt <= contactFreshness else {
                reset() // Missing stop/contact frames must fail open.
                return false
            }
            if ownsTouch {
                lastSuppressedAt = time
                return true
            }
            return false
        }
        guard let release = releasedAt, time >= release else { return false }
        let age = time - release
        if age <= releaseGrace
            || (isMomentum && age <= maximumTailDuration && time - lastSuppressedAt <= momentumSilence) {
            lastSuppressedAt = time
            return true
        }
        // A new direct scroll (even before its raw contacts arrive) is not the
        // residual inertia of the PK gesture.
        if !isMomentum || age > maximumTailDuration { releasedAt = nil }
        return false
    }

    mutating func reset() {
        fingers = 0
        lastContactsAt = -.infinity
        ownsTouch = false
        exceededRequiredCount = false
        releasedAt = nil
        lastSuppressedAt = -.infinity
    }
}
