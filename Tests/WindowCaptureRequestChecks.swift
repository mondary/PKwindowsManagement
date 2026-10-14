import Foundation

@main
enum WindowCaptureRequestChecks {
    static func main() async {
        let immediate = await WindowCaptureRequest<Int>.perform(timeout: 0.02) { complete in
            complete(42)
            complete(99) // Duplicate callbacks must not double-resume.
        }
        precondition(immediate == 42)
        let started = ProcessInfo.processInfo.systemUptime
        let missing = await WindowCaptureRequest<Int>.perform(timeout: 0.02) { _ in }
        precondition(missing == nil)
        precondition(ProcessInfo.processInfo.systemUptime - started < 1)
        let late = await WindowCaptureRequest<Int>.perform(timeout: 0.01) { complete in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { complete(7) }
        }
        precondition(late == nil)
        let cancelled = Task {
            await WindowCaptureRequest<Int>.perform(timeout: 10) { _ in }
        }
        cancelled.cancel()
        let cancelledResult = await cancelled.value
        precondition(cancelledResult == nil)
        // Exercise timeout/cancellation/callback races on independent requests.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let task = Task {
                        await WindowCaptureRequest<Int>.perform(timeout: 0.001) { complete in
                            DispatchQueue.global().async { complete(1); complete(2) }
                        }
                    }
                    task.cancel()
                    let value = await task.value
                    precondition(value == nil || value == 1)
                }
            }
        }
        try? await Task.sleep(nanoseconds: 100_000_000) // Let late callbacks fire.
        print("Capture lifecycle checks passed: timeout, missing/late/duplicate callbacks, early cancellation and 100 races")
    }
}
