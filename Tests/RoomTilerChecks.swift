import CoreGraphics
import Foundation

// Standalone geometry check: keep the cases in sync with RoomLayoutKind so the
// tiler can be tested without loading the full AppKit/SwiftUI application.
enum RoomLayoutKind { case auto, focus, columns, grid, stack, dwindle, monocle }

@main
enum RoomTilerChecks {
    static func main() {
        let area = CGRect(x: -1920, y: 32, width: 1920, height: 1080)
        for count in 1...8 {
            let frames = RoomTiler.frames(count: count, kind: .dwindle, in: area)
            precondition(frames.count == count)
            for (index, frame) in frames.enumerated() {
                precondition(frame.width > 0 && frame.height > 0)
                precondition(area.contains(frame))
                for other in frames.dropFirst(index + 1) {
                    precondition(frame.intersection(other).isNull)
                }
            }
            let monocle = RoomTiler.frames(count: count, kind: .monocle, in: area)
            precondition(monocle.count == count)
            precondition(monocle.allSatisfy { $0 == monocle[0] })
        }
        precondition(RoomTiler.frames(count: 0, kind: .dwindle, in: area).isEmpty)
        print("Room tiler checks passed")
    }
}
