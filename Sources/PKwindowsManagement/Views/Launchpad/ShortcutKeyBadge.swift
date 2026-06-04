import SwiftUI

struct ShortcutKeyBadge: View {
    let shortcut: KeyboardShortcutSetting
    var compact = false

    private var keys: [String] {
        shortcut.modifier.keySymbols + [shortcut.key.uppercased()]
    }

    var body: some View {
        HStack(spacing: compact ? 2 : 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: compact ? 14 : 17, minHeight: compact ? 14 : 17)
                    .padding(.horizontal, key.count > 1 ? 2 : 0)
                    .background(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous)
                            .stroke(.white.opacity(0.45), lineWidth: 0.7)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            }
        }
        .padding(compact ? 3 : 4)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: compact ? 7 : 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 7 : 9, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.32), radius: 4, y: 2)
    }
}
