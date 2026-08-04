import SwiftUI

struct CompactShortcutField: View {
    let shortcut: Binding<KeyboardShortcutSetting?>

    @StateObject private var recorder = ShortcutRecorderController()

    private var recorderBinding: Binding<KeyboardShortcutSetting> {
        Binding(
            get: { shortcut.wrappedValue ?? .init(key: "", modifier: .controlOption) },
            set: { shortcut.wrappedValue = $0 }
        )
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(displayString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(shortcut.wrappedValue == nil ? Color.secondary : Color.primary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .frame(minWidth: 64, alignment: .leading)

            Button(recorder.isRecording ? "Stop" : "Record") {
                if recorder.isRecording {
                    recorder.stop()
                } else {
                    recorder.start(shortcut: recorderBinding)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(recorder.isRecording ? .orange : .accentColor)
            .frame(minWidth: 52)
        }
        .onDisappear {
            recorder.stop()
        }
    }

    private var displayString: String {
        guard let shortcut = shortcut.wrappedValue, !shortcut.key.isEmpty else { return "—" }
        return "\(shortcut.modifier.symbolPrefix)\(shortcut.keyDisplayName)"
    }
}
