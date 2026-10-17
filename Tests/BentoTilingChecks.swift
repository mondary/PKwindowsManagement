import CoreGraphics
import Foundation

@main
enum BentoTilingChecks {
    static func covers(_ frames: [CGRect], _ area: CGRect) {
        precondition(!frames.isEmpty)
        var covered: CGFloat = 0
        for (index, frame) in frames.enumerated() {
            precondition(frame.width > 0 && frame.height > 0)
            precondition(area.contains(frame), "cell crosses a display edge")
            covered += frame.width * frame.height
            for other in frames.dropFirst(index + 1) {
                let overlap = frame.intersection(other)
                precondition(overlap.isNull || overlap.width * overlap.height == 0, "overlapping cells")
            }
        }
        precondition(abs(covered - area.width * area.height) < 0.01, "unfilled area")
    }

    static func main() {
        let desktops: Set<UInt64> = [10, 11, 20]
        func desktop(_ membership: [UInt64]?, _ scope: BentoTiling.Scope, current: UInt64? = 10) -> UInt64? {
            BentoTiling.desktop(for: membership, scope: scope, current: current, userDesktops: desktops)
        }
        precondition(desktop([10], .currentDesktop) == 10)
        precondition(desktop([11], .currentDesktop) == nil)
        // Desktop 20 may be visible on a second display; it is still not 10.
        precondition(desktop([20], .currentDesktop) == nil)
        precondition(desktop([20], .currentDesktop, current: 20) == 20)
        precondition(desktop([10], .currentDesktop, current: nil) == nil)
        for scope in [BentoTiling.Scope.currentDesktop, .allDesktops] {
            precondition(desktop(nil, scope) == nil)
            precondition(desktop([], scope) == nil)
            precondition(desktop([10, 11], scope) == nil, "shared windows would affect another desktop")
            precondition(desktop([99], scope) == nil, "fullscreen Spaces are not tiled")
        }
        for id in desktops { precondition(desktop([id], .allDesktops) == id) }
        precondition(desktop([11], .allDesktops, current: nil) == 11)

        let areas = [
            CGRect(x: 0, y: 25, width: 1512, height: 900),
            CGRect(x: -1920, y: -1080, width: 1920, height: 1055),
            CGRect(x: 100, y: -2100, width: 1081, height: 1919),
            CGRect(x: -3840, y: 40, width: 3840, height: 1559),
            CGRect(x: 0, y: 0, width: 800, height: 600),
            CGRect(x: 0.5, y: -100.5, width: 1727.5, height: 997.5)
        ]
        for area in areas {
            for count in 1...64 {
                for transposed in [false, true] {
                    let frames = CanvasLayout.bentoFrames(in: area, windows: count, transposed: transposed)
                    precondition(frames.count == min(count, 12))
                    covers(frames, area)
                }
                let plan = CanvasLayout.bentoPlan(in: area, minimumSizes: Array(repeating: .zero, count: count))
                precondition(plan.count <= min(count, 12))
                covers(plan, area)
                if plan.count > 1 {
                    precondition(plan.allSatisfy { $0.width >= 420 && $0.height >= 280 })
                }
            }
        }
        precondition(CanvasLayout.bentoFrames(in: areas[0], windows: 0).isEmpty)
        precondition(CanvasLayout.bentoPlan(in: .zero, minimumSizes: [.zero]).isEmpty)
        let four = CanvasLayout.bentoFrames(in: areas[0], windows: 4)
        precondition(four.allSatisfy { $0.width == 756 && $0.height == 450 })
        let twelve = CanvasLayout.bentoFrames(in: areas[3], windows: 12)
        precondition(twelve[0].height >= twelve.last!.height * 1.9, "12 must retain larger priority windows")
        precondition(CanvasLayout.bentoPlan(in: areas[0], minimumSizes: Array(repeating: .zero, count: 24)).count == 8)
        precondition(CanvasLayout.bentoPlan(in: areas[3], minimumSizes: Array(repeating: .zero, count: 24)).count == 12)

        // A refused minimum width forces fewer, larger cells; touched overflow
        // windows are restored. The final accepted cells must still fill the area.
        let area = areas[0]
        var current: [Int: CGRect] = [:]
        var restored = Set<Int>()
        let selected = BentoTiling.arrange(in: area, count: 20, apply: { index, target in
            var actual = target
            if index == 2 { actual.size.width = max(800, target.width) }
            current[index] = actual
            return actual
        }, restore: { index in current.removeValue(forKey: index); restored.insert(index) })
        precondition(!selected.isEmpty && selected.count < 8)
        precondition(Set(current.keys) == Set(selected))
        precondition(restored.contains(2))
        covers(selected.map { current[$0]! }, area)

        // Closed/unmovable and fixed-size windows must not reserve empty slots.
        current = [:]
        let survivors = BentoTiling.arrange(in: area, count: 8, apply: { index, target in
            if index == 0 { return nil }
            if index == 3 { return CGRect(origin: target.origin, size: CGSize(width: 100, height: 100)) }
            current[index] = target
            return target
        }, restore: { current.removeValue(forKey: $0) })
        precondition(!survivors.contains(0) && !survivors.contains(3))
        precondition(survivors.count == 6)
        covers(survivors.map { current[$0]! }, area)

        var calls = 0
        let cancelled = BentoTiling.arrange(in: area, count: 12, apply: { _, target in
            calls += 1
            return target
        }, restore: { _ in preconditionFailure("cancelled work must not restore over a new command") },
            valid: { calls == 0 })
        precondition(cancelled.isEmpty && calls == 1)
        let impossible = BentoTiling.arrange(in: area, count: 1, apply: { _, target in
            CGRect(origin: target.origin, size: CGSize(width: 9000, height: 9000))
        }, restore: { _ in calls += 1 })
        precondition(impossible.isEmpty && calls == 2)
        current = [:]
        let afterImpossible = BentoTiling.arrange(in: area, count: 4, apply: { index, target in
            if index == 0 { return CGRect(origin: target.origin, size: CGSize(width: 9000, height: 9000)) }
            current[index] = target
            return target
        }, restore: { current.removeValue(forKey: $0) })
        precondition(afterImpossible == [1, 2, 3])
        covers(afterImpossible.map { current[$0]! }, area)
        print("Bento passed: current/all desktop isolation, shared/unknown/fullscreen exclusions, full coverage, no overlap, 1–64 windows, adaptive capacity, AX refusals and cancellation")
    }
}
