import AppKit
import SwiftUI

/// Guarantees "type to search" in overlay panels: while the overlay is open,
/// printable keystrokes land in the search field even if focus has not
/// settled yet (panel activation races the first keystrokes). Keys are only
/// redirected when the field does not already own them and no other text
/// editor (sheet field, recorder) has the keyboard.
struct SearchKickstarter: NSViewRepresentable {
    @Binding var query: String
    /// True when the search field owns keyboard focus.
    let isFocused: () -> Bool
    /// Moves focus into the search field.
    let focus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(query: $query, isFocused: isFocused, focus: focus)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.query = $query
        context.coordinator.isFocused = isFocused
        context.coordinator.focus = focus
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var query: Binding<String>
        var isFocused: () -> Bool
        var focus: () -> Void
        private var monitor: Any?

        init(query: Binding<String>, isFocused: @escaping () -> Bool, focus: @escaping () -> Void) {
            self.query = query
            self.isFocused = isFocused
            self.focus = focus
        }

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                // Only our own key window: sheets and alerts keep their keys.
                guard let key = NSApp.keyWindow,
                      event.window == nil || event.window === key
                else { return event }
                // Another text editor (recorder, sheet field) keeps its keys.
                if let responder = key.firstResponder, responder is NSTextView, !self.isFocused() {
                    return event
                }
                if self.isFocused() { return event }
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard modifiers.isEmpty || modifiers == .shift else { return event }
                guard !event.isARepeat,
                      let characters = event.charactersIgnoringModifiers,
                      !characters.isEmpty
                else { return event }
                let scalar = characters.unicodeScalars.first!
                guard CharacterSet.alphanumerics.contains(scalar) || scalar == " "
                else { return event }
                let text = characters
                DispatchQueue.main.async {
                    self.query.wrappedValue.append(text)
                    self.focus()
                }
                return nil
            }
        }

        func stop() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        deinit { stop() }
    }
}
