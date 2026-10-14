import Foundation

/// ScreenCaptureKit callbacks can arrive after dismissal (or never arrive).
/// Bound each request and resume its continuation exactly once in every race.
final class WindowCaptureRequest<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value?, Never>?
    private var finished = false
    private var result: Value?

    static func perform(timeout: TimeInterval = 3,
                        start: (@escaping (Value?) -> Void) -> Void) async -> Value? {
        let request = WindowCaptureRequest<Value>()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard request.install(continuation) else { return }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    request.finish(nil)
                }
                start { request.finish($0) }
            }
        } onCancel: {
            request.finish(nil)
        }
    }

    private func install(_ continuation: CheckedContinuation<Value?, Never>) -> Bool {
        lock.lock()
        if finished {
            let result = result
            lock.unlock()
            continuation.resume(returning: result)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    private func finish(_ result: Value?) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        self.result = result
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: result)
    }
}
