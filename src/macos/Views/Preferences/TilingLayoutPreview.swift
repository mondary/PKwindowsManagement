import SwiftUI

struct TilingLayoutPreview: View {
    let layout: TilingLayoutKind
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPlaying = true

    private var paused: Bool { !isSelected || !isPlaying || reduceMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(layout.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    isPlaying.toggle()
                } label: {
                    Label(isPlaying ? localizedString("Pause preview") : localizedString("Play preview"),
                          systemImage: isPlaying ? "pause.fill" : "play.fill")
                }
                .labelStyle(.iconOnly)
                .help(isPlaying ? localizedString("Pause preview") : localizedString("Play preview"))
                .accessibilityLabel(isPlaying ? localizedString("Pause preview") : localizedString("Play preview"))
                Button {
                    frozenStep = 1
                    isPlaying = true
                    previewStart = Date()
                } label: {
                    Label(localizedString("Replay preview"), systemImage: "arrow.counterclockwise")
                }
                .labelStyle(.iconOnly)
                .help(localizedString("Replay preview"))
            }

            TimelineView(.animation(minimumInterval: 1.1, paused: paused)) { timeline in
                let step: Int
                if reduceMotion {
                    step = 6
                } else if isPlaying {
                    step = Int(timeline.date.timeIntervalSince(previewStart) / 1.1).modulo(6) + 1
                } else {
                    step = frozenStep
                }
                preview(count: step)
            }
            .frame(height: 196)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityLabel(String(format: localizedString("%@ layout preview, %d windows"), layout.title, 6))
        }
        .onChange(of: isPlaying) { playing in
            if !playing { frozenStep = currentStep }
            else {
                previewStart = Date().addingTimeInterval(-Double(max(0, frozenStep - 1)) * 1.1)
            }
        }
        .onChange(of: layout) { _ in
            previewStart = Date()
            frozenStep = 1
            isPlaying = true
        }
    }

    @State private var previewStart = Date()
    @State private var frozenStep = 1

    private var currentStep: Int {
        if reduceMotion { return 6 }
        return Int(Date().timeIntervalSince(previewStart) / 1.1).modulo(6) + 1
    }

    private func preview(count: Int) -> some View {
        GeometryReader { proxy in
            let area = CGRect(x: 0, y: 0, width: proxy.size.width, height: proxy.size.height)
            let frames = TilingLayoutGeometry.frames(kind: layout, count: count, in: area,
                selectedIndex: count - 1)
            let resolvedLayout = TilingLayoutGeometry.resolvedKind(kind: layout, count: count, in: area)
            let canvasVisible = TilingLayoutGeometry.canvasVisibleIndices(count: count, in: area,
                selectedIndex: count - 1)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor))
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(index == frames.count - 1
                              ? Color.accentColor.opacity(0.34)
                              : Color(NSColor.controlAccentColor).opacity(0.14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(index == frames.count - 1 ? 0.9 : 0.38), lineWidth: 1)
                        }
                        .overlay {
                            Text(String(index + 1))
                                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                        .frame(width: max(1, frame.width), height: max(1, frame.height))
                        .position(x: frame.midX, y: frame.midY)
                        .zIndex(Double(index))
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .accessibilityLabel(String(format: localizedString("Window %d"), index + 1))
                }
            }
            .animation(.easeInOut(duration: 0.4), value: count)
            .overlay(alignment: .topTrailing) {
                if layout == .canvas {
                    HStack(spacing: 3) {
                        ForEach(0..<count, id: \.self) { index in
                            Capsule()
                                .fill(canvasVisible.contains(index) ? Color.accentColor : Color.secondary.opacity(0.32))
                                .frame(width: 10, height: 3)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(localizedString("Horizontal Canvas minimap"))
                }
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    if layout == .automatic {
                        Text(String(format: localizedString("Automatic resolves to %@"), resolvedLayout.title))
                    }
                    Text(String(format: localizedString("%d of 6 windows"), count))
                        .monospacedDigit()
                }
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
                .padding(8)
            }
        }
    }
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        (self % divisor + divisor) % divisor
    }
}
