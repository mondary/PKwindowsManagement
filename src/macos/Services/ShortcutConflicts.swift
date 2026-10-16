import AppKit
import Combine
import Foundation

/// Tout détenteur d'un raccourci global : commande de fenêtre, Launchpad,
/// Rooms ou lancement d'app/script. Sert à repérer les doublons et à dire qui
/// s'exécute réellement quand plusieurs lignes partagent la même combinaison.
struct ShortcutBindingRef: Identifiable, Equatable {
    enum Kind: Equatable {
        case windowAction(ShortcutAction)
        case launchpad
        case rooms
        case launch(id: String)

        /// Les raccourcis d'action et de lancement se retirent depuis les
        /// réglages ; Launchpad et Rooms appartiennent à d'autres pages.
        var isClearable: Bool {
            switch self {
            case .windowAction, .launch: true
            case .launchpad, .rooms: false
            }
        }

        /// Enregistrés par le système (Carbon) : macOS exige la combinaison
        /// exacte, contrairement au tap d'événements qui teste « contient ».
        var isSystemRegistered: Bool {
            switch self {
            case .launchpad, .rooms: true
            case .windowAction, .launch: false
            }
        }
    }

    let kind: Kind
    let title: String
    let shortcut: KeyboardShortcutSetting

    var id: String {
        switch kind {
        case .windowAction(let action): "action.\(action.rawValue)"
        case .launchpad: "launchpad"
        case .rooms: "rooms"
        case .launch(let id): "launch.\(id)"
        }
    }
}

/// Doublons d'une même combinaison, triés dans l'ordre réel de déclenchement :
/// le premier s'exécute, les suivants restent inertes tant qu'ils partagent la
/// touche.
struct ShortcutConflictGroup: Identifiable {
    /// Du gagnant au perdant.
    let bindings: [ShortcutBindingRef]

    var id: String { bindings.map(\.id).joined(separator: "|") }
    var shortcut: KeyboardShortcutSetting { bindings[0].shortcut }
    var winner: ShortcutBindingRef { bindings[0] }
    var others: [ShortcutBindingRef] { Array(bindings.dropFirst()) }
}

enum ShortcutConflictEngine {
    /// Regroupe les liaisons qui se chevauchent : un groupe de plus d'une
    /// liaison est un conflit à montrer. Le regroupement se fait autour de la
    /// première liaison rencontrée, suffisant pour l'avertissement.
    static func conflictGroups(_ bindings: [ShortcutBindingRef]) -> [ShortcutConflictGroup] {
        var groups: [[ShortcutBindingRef]] = []
        for binding in bindings where !binding.shortcut.key.isEmpty {
            if let index = groups.firstIndex(where: { collides($0[0], binding) }) {
                groups[index].append(binding)
            } else {
                groups.append([binding])
            }
        }
        return groups
            .filter { $0.count > 1 }
            .map { ShortcutConflictGroup(bindings: $0.sorted { dispatchRank($0) < dispatchRank($1) }) }
            .sorted {
                ($0.shortcut.key, $0.shortcut.modifier.rawValue, $0.winner.title)
                    < ($1.shortcut.key, $1.shortcut.modifier.rawValue, $1.winner.title)
            }
    }

    /// Deux liaisons se croisent-elles réellement ? Même touche et
    /// modificateurs compatibles ; dès qu'un des deux est enregistré par le
    /// système (Carbon), la combinaison doit être exacte — ⌥Espace ne bloque
    /// pas ⌃⌥Espace.
    static func collides(_ lhs: ShortcutBindingRef, _ rhs: ShortcutBindingRef) -> Bool {
        guard lhs.shortcut.collides(with: rhs.shortcut) else { return false }
        if lhs.kind.isSystemRegistered != rhs.kind.isSystemRegistered {
            return lhs.shortcut.modifier.flags == rhs.shortcut.modifier.flags
        }
        return true
    }

    /// Ordre réel de déclenchement, calqué sur LaunchShortcutMonitor : les
    /// raccourcis système (Launchpad, Rooms) répondent en premier, puis le
    /// sélecteur de fenêtres, puis les lancements quand une autre app est au
    /// premier plan, puis le placement de fenêtres, les bureaux et le Canvas.
    /// Rang plus bas = s'exécute plus tôt.
    static func dispatchRank(_ binding: ShortcutBindingRef) -> Int {
        switch binding.kind {
        case .launchpad: return 10
        case .rooms: return 11
        case .launch: return 30
        case .windowAction(let action):
            if action == .windowSwitcherToggle { return 20 }
            let index = ShortcutAction.allCases.firstIndex(of: action) ?? 0
            if action.spaceAction != nil { return 300 + index }
            if action.canvasAction != nil { return 400 + index }
            return 100 + index
        }
    }
}

extension KeyboardShortcutSetting {
    /// Vrai quand une même pression peut déclencher les deux liaisons : même
    /// touche et modificateurs compatibles (⌘ vs ⌘L se chevauchent, ⌘L vs ⌘R
    /// jamais).
    func collides(with other: KeyboardShortcutSetting) -> Bool {
        let mine = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let theirs = other.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !mine.isEmpty, mine == theirs else { return false }
        return modifier.overlaps(other.modifier)
    }
}

extension ShortcutModifierPreset {
    /// Un pré-réglage couvre l'autre quand ses drapeaux contiennent ceux de
    /// l'autre — deux côtés opposés d'un même modificateur ne se croisent
    /// jamais (⌘L + ⌘R peuvent coexister sur la même touche).
    func overlaps(_ other: ShortcutModifierPreset) -> Bool {
        if let side, let otherSide = other.side, side != otherSide { return false }
        return flags.isSuperset(of: other.flags) || other.flags.isSuperset(of: flags)
    }

    private enum Side: Equatable { case left, right }

    private var side: Side? {
        switch self {
        case .leftCommand, .leftOption, .leftShift: .left
        case .rightCommand, .rightOption, .rightShift: .right
        default: nil
        }
    }
}

/// Dernier refus d'enregistrement d'un raccourci système (Carbon) : macOS
/// n'accorde une combinaison globale qu'à un seul demandeur, l'échec serait
/// sinon invisible dans les réglages.
final class ShortcutRegistrationFeedback: ObservableObject {
    static let shared = ShortcutRegistrationFeedback()

    struct Refusal: Identifiable, Equatable {
        let id: String
        let title: String
        let shortcut: KeyboardShortcutSetting
    }

    @Published private(set) var refusals: [Refusal] = []

    func report(id: String, title: String, shortcut: KeyboardShortcutSetting, accepted: Bool) {
        if accepted {
            refusals.removeAll { $0.id == id }
        } else if let index = refusals.firstIndex(where: { $0.id == id }) {
            refusals[index] = Refusal(id: id, title: title, shortcut: shortcut)
        } else {
            refusals.append(Refusal(id: id, title: title, shortcut: shortcut))
        }
    }
}
