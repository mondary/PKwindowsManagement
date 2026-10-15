import Foundation

@main
enum WindowCloseRequestChecks {
    static func main() {
        var presses = 0
        var observations = 0
        var pauses = 0
        func press() -> Bool { presses += 1; return true }
        func closed() -> Bool { observations += 1; return observations == 3 }

        let stale = WindowCloseRequest.run(isCancelled: { false }, validate: { false },
            press: press, isClosed: closed, pause: {})
        precondition(stale == .unavailable && presses == 0 && observations == 0)

        let cancelled = WindowCloseRequest.run(isCancelled: { true }, validate: { fatalError("Should not validate") },
            press: press, isClosed: closed, pause: {})
        precondition(cancelled == .cancelled && presses == 0)

        var cancellation = false
        let cancelledDuringValidation = WindowCloseRequest.run(isCancelled: { cancellation },
            validate: { cancellation = true; return true }, press: press, isClosed: closed, pause: {})
        precondition(cancelledDuringValidation == .cancelled && presses == 0)

        let refusal = WindowCloseRequest.run(isCancelled: { false }, validate: { true },
            press: { false }, isClosed: closed, pause: {})
        precondition(refusal == .failed && observations == 0)

        let success = WindowCloseRequest.run(isCancelled: { false }, validate: { true },
            press: press, isClosed: closed, pause: { pauses += 1 })
        precondition(success == .closed && presses == 1 && observations == 3 && pauses == 2)

        presses = 0
        observations = 0
        pauses = 0
        let saveDialog = WindowCloseRequest.run(isCancelled: { false }, validate: { true },
            press: press, isClosed: { observations += 1; return false }, pause: { pauses += 1 })
        precondition(saveDialog == .pending && presses == 1 && observations == 16 && pauses == 16)

        presses = 0
        observations = 0
        cancellation = false
        let pickerDismissed = WindowCloseRequest.run(isCancelled: { cancellation }, validate: { true },
            press: press, isClosed: { observations += 1; return false }, pause: { cancellation = true })
        precondition(pickerDismissed == .cancelled && presses == 1 && observations == 1)
        print("Window close checks passed: stale identity, cancellation, rejection, confirmed closure, save-dialog timeout, single press")
    }
}
