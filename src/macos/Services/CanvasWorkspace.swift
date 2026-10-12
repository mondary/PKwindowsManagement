import CoreGraphics

struct CanvasWorkspace: Hashable {
    let displayID: UInt32
    let spaceID: UInt64
}

enum CanvasWorkspacePolicy {
    enum State { case active, suspended, disconnected }

    static func state(ownedSpace: UInt64, currentSpace: UInt64?, displayConnected: Bool) -> State {
        guard displayConnected else { return .disconnected }
        // An unknown Space during Mission Control is not a closed desktop.
        return currentSpace == ownedSpace ? .active : .suspended
    }
}
