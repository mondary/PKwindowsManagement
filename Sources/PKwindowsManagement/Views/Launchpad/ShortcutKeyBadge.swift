import SwiftUI

struct ShortcutKeyBadge: View {
    let shortcut: KeyboardShortcutSetting
    var compact = false

    private var keys: [String] {
        shortcut.modifier.keySymbols + [shortcut.key.uppercased()]
    }

    private var keyFontSize: CGFloat { compact ? 9 : 10 }
    private var keyMinSide: CGFloat { compact ? 17 : 20 }
    private var keyCornerRadius: CGFloat { compact ? 5 : 6 }
    private var outerCornerRadius: CGFloat { compact ? 9 : 11 }

    var body: some View {
        HStack(spacing: compact ? 2 : 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: keyFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: max(keyMinSide, CGFloat(key.count) * 8), minHeight: keyMinSide)
                    .padding(.horizontal, key.count > 1 ? 3 : 0)
                    .background(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: keyCornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: keyCornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.45), lineWidth: 0.7)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            }
        }
        .padding(compact ? 3 : 4)
        .background(.black.opacity(0.66), in: RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.32), radius: 4, y: 2)
    }
}
