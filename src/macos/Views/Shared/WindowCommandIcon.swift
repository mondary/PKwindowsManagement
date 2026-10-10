import SwiftUI

/// Miniature de placement : la fraction active est remplie, le reste reste fantôme.
struct WindowPlacementGlyph: View {
    let fraction: CGRect
    var tint: Color = .accentColor

    private let canvasW: CGFloat = 15
    private let canvasH: CGFloat = 12
    private let gap: CGFloat = 1

    var body: some View {
        // Garde-fou : une fraction nulle rendrait la division infinie (crash)
        let width = max(0.05, min(1, fraction.width))
        let height = max(0.05, min(1, fraction.height))

        // Fenêtre flottante centrée (ex. Taille raisonnable) : contour + rectangle intérieur
        if fraction.minX > 0.01, fraction.minY > 0.01,
           fraction.maxX < 0.99, fraction.maxY < 0.99 {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(tint.opacity(0.55), lineWidth: 1)
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(tint)
                    .frame(width: max(2, canvasW * width), height: max(2, canvasH * height))
            }
            .frame(width: canvasW, height: canvasH)
        } else {
            // Dénominateur du découpage : l'entier n (2…6) qui aligne le mieux
            // la largeur sur k/n — deux tiers → 3 colonnes, trois quarts → 4…
            let cols = width >= 0.99 ? 1 : bestDenominator(width)
            let rows = height >= 0.99 ? 1 : bestDenominator(height)
            let activeCols = Int((width * CGFloat(cols)).rounded())
            let activeRows = Int((height * CGFloat(rows)).rounded())
            let colStart = max(0, min(Int((fraction.minX * CGFloat(cols)).rounded()), cols - activeCols))
            let rowStart = max(0, min(Int((fraction.minY * CGFloat(rows)).rounded()), rows - activeRows))
            let colEnd = colStart + activeCols
            let rowEnd = rowStart + activeRows

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { col in
                            let active = col >= colStart && col < colEnd && row >= rowStart && row < rowEnd
                            RoundedRectangle(cornerRadius: 1.2)
                                .fill(active ? tint : tint.opacity(0.18))
                        }
                    }
                }
            }
            .frame(width: canvasW, height: canvasH)
        }
    }

    // L'entier n (2…6) qui aligne le mieux `value` sur k/n :
    // 0.667 → 3 (deux tiers), 0.75 → 4 (trois quarts), 0.5 → 2…
    private func bestDenominator(_ value: CGFloat) -> Int {
        var best = 2
        var bestError = CGFloat.greatestFiniteMagnitude
        for n in 2...6 {
            let k = (value * CGFloat(n)).rounded()
            let error = abs(value - k / CGFloat(n))
            if error < bestError - 0.0001 {
                bestError = error
                best = n
            }
        }
        return best
    }
}

/// Icône d'une commande de fenêtre, identique dans les listes de réglages et la
/// carte clavier : glyph de placement, double écran, pile d'app ou SF Symbol.
struct WindowCommandIcon: View {
    let spec: WindowCommandSpec
    var tint: Color = .accentColor

    var body: some View {
        if let fraction = spec.fraction {
            WindowPlacementGlyph(fraction: fraction, tint: tint)
        } else if spec.action == .windowMaximizeAll {
            allScreens
        } else if spec.action == .windowMaximizeAllInApp {
            appStack
        } else {
            Image(systemName: spec.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    // Deux écrans côte à côte, chacun avec sa fenêtre presque pleine
    private var allScreens: some View {
        HStack(spacing: 1.5) {
            miniScreen
            miniScreen
        }
        .frame(width: 15, height: 12)
    }

    private var miniScreen: some View {
        RoundedRectangle(cornerRadius: 1.2)
            .stroke(tint.opacity(0.55), lineWidth: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 0.8)
                    .fill(tint)
                    .padding(1.5)
            )
    }

    // Un écran avec deux fenêtres empilées de l'app active
    private var appStack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(tint.opacity(0.55), lineWidth: 1)
            RoundedRectangle(cornerRadius: 1)
                .fill(tint.opacity(0.4))
                .frame(width: 9, height: 7)
                .offset(x: -1.5, y: -1.5)
            RoundedRectangle(cornerRadius: 1)
                .fill(tint)
                .frame(width: 9, height: 7)
                .offset(x: 1.5, y: 1.5)
        }
        .frame(width: 15, height: 12)
    }
}
