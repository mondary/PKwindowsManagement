import Foundation

@main
enum ShortcutConflictChecks {
    static func binding(_ kind: ShortcutBindingRef.Kind, _ title: String, _ key: String, _ modifier: ShortcutModifierPreset) -> ShortcutBindingRef {
        ShortcutBindingRef(kind: kind, title: title, shortcut: .init(key: key, modifier: modifier))
    }

    static func main() {
        // The previous tiling binding now targets only the current desktop.
        // The broader action is opt-in, never silently assigned the same key.
        precondition(ShortcutAction(rawValue: "windowTileAll") == .windowTileAll)
        precondition(ShortcutAction.windowTileAll.defaultShortcut == .init(key: "t", modifier: .controlOption))
        precondition(ShortcutAction.windowTileAllDesktops.defaultShortcut == nil)
        let controlOption = ShortcutModifierPreset.controlOption
        let controlShift = ShortcutModifierPreset.controlShift

        // Même touche et mêmes modificateurs : collision.
        assert(KeyboardShortcutSetting(key: "left", modifier: controlShift)
            .collides(with: .init(key: "left", modifier: controlShift)))
        // Touches différentes : jamais.
        assert(!KeyboardShortcutSetting(key: "left", modifier: controlShift)
            .collides(with: .init(key: "right", modifier: controlShift)))
        // Modificateurs incompatibles (⌃⌥ vs ⌃⇧).
        assert(!KeyboardShortcutSetting(key: "t", modifier: controlOption)
            .collides(with: .init(key: "t", modifier: controlShift)))
        // Casse ignorée.
        assert(KeyboardShortcutSetting(key: "T", modifier: controlOption)
            .collides(with: .init(key: "t", modifier: controlOption)))

        // ⌥ et ⌃⌥ se chevauchent (⌃⌥ satisfait ⌥), ⌘ et ⌘L aussi.
        assert(KeyboardShortcutSetting(key: "n", modifier: .option)
            .collides(with: .init(key: "n", modifier: controlOption)))
        assert(KeyboardShortcutSetting(key: "n", modifier: .command)
            .collides(with: .init(key: "n", modifier: .leftCommand)))
        // Côtés opposés : ⌘L et ⌘R coexistent sur la même touche.
        assert(!KeyboardShortcutSetting(key: "n", modifier: .leftCommand)
            .collides(with: .init(key: "n", modifier: .rightCommand)))
        assert(!KeyboardShortcutSetting(key: "n", modifier: .leftOption)
            .collides(with: .init(key: "n", modifier: .rightOption)))
        // Fn+⇧ et ⇧ se chevauchent.
        assert(KeyboardShortcutSetting(key: "m", modifier: .fnShift)
            .collides(with: .init(key: "m", modifier: .shift)))

        // Cas réel : Previous Display et Move Window to Previous Desktop sur ⌃⇧←.
        let previousDisplay = binding(.windowAction(.windowPreviousDisplay), "Previous Display", "left", .controlShift)
        let previousDesktop = binding(.windowAction(.windowPreviousDesktop), "Move Window to Previous Desktop", "left", .controlShift)
        let unique = binding(.windowAction(.windowLeftHalf), "Left Half", "left", .controlOption)
        let groups = ShortcutConflictEngine.conflictGroups([previousDisplay, previousDesktop, unique])
        assert(groups.count == 1)
        assert(groups[0].bindings.count == 2)
        // Le placement de fenêtres passe avant les bureaux : c'est Previous
        // Display qui s'exécute.
        assert(groups[0].winner.id == "action.windowPreviousDisplay")
        assert(groups[0].others.map(\.id) == ["action.windowPreviousDesktop"])

        // Sans doublon, aucun groupe.
        assert(ShortcutConflictEngine.conflictGroups([unique]).isEmpty)
        // Une touche vide ne participe jamais.
        assert(ShortcutConflictEngine.conflictGroups([
            binding(.launchpad, "Launchpad", "", .option),
            binding(.rooms, "Rooms", "", .option)
        ]).isEmpty)

        // Priorités : sélecteur de fenêtres > placement > bureaux > Canvas.
        let switcher = binding(.windowAction(.windowSwitcherToggle), "Open Window Previews", "t", .controlOption)
        let leftHalf = binding(.windowAction(.windowLeftHalf), "Left Half", "t", .controlOption)
        let spaceMove = binding(.windowAction(.desktopMoveLeft), "Move Desktop Left", "t", .controlOption)
        let canvas = binding(.windowAction(.canvasToggle), "Toggle Horizontal Canvas", "t", .controlOption)
        assert(ShortcutConflictEngine.dispatchRank(switcher) < ShortcutConflictEngine.dispatchRank(leftHalf))
        assert(ShortcutConflictEngine.dispatchRank(leftHalf) < ShortcutConflictEngine.dispatchRank(spaceMove))
        assert(ShortcutConflictEngine.dispatchRank(spaceMove) < ShortcutConflictEngine.dispatchRank(canvas))

        let mixed = ShortcutConflictEngine.conflictGroups([canvas, leftHalf, switcher, spaceMove])
        assert(mixed.count == 1)
        assert(mixed[0].bindings.map(\.id) == [
            "action.windowSwitcherToggle",
            "action.windowLeftHalf",
            "action.desktopMoveLeft",
            "action.canvasToggle"
        ])

        // Le lancement d'app cède devant le sélecteur, mais gagne quand notre
        // app est en arrière-plan (le sélecteur reste devant).
        let launch = binding(.launch(id: "com.example.app"), "Example", "t", .controlOption)
        assert(ShortcutConflictEngine.dispatchRank(switcher) < ShortcutConflictEngine.dispatchRank(launch))
        assert(ShortcutConflictEngine.dispatchRank(launch) < ShortcutConflictEngine.dispatchRank(leftHalf))

        // Launchpad et Rooms sont enregistrés par le système : ils répondent
        // avant tout le reste.
        assert(ShortcutConflictEngine.dispatchRank(binding(.launchpad, "Launchpad", "t", .controlOption)) < ShortcutConflictEngine.dispatchRank(switcher))

        // Un raccourci système exige la combinaison exacte : ⌥Espace ne bloque
        // pas ⌃⌥Espace, mais il bloque une action ⌥Espace.
        let launchpad = binding(.launchpad, "Launchpad", "space", .option)
        let nextDisplay = binding(.windowAction(.windowNextDisplay), "Next Display", "space", .controlOption)
        let canvasToggle = binding(.windowAction(.canvasToggle), "Toggle Horizontal Canvas", "space", .option)
        assert(ShortcutConflictEngine.conflictGroups([launchpad, nextDisplay]).isEmpty)
        assert(ShortcutConflictEngine.conflictGroups([launchpad, canvasToggle]).count == 1)
        assert(ShortcutConflictEngine.conflictGroups([launchpad, canvasToggle])[0].winner.id == "launchpad")
        // Rooms ⌃⌥R face à une action ⌃⌥R : conflit réel.
        let rooms = binding(.rooms, "Rooms", "r", .controlOption)
        let actionOnR = binding(.windowAction(.windowTopRight), "Top Right", "r", .controlOption)
        assert(ShortcutConflictEngine.conflictGroups([rooms, actionOnR]).count == 1)

        // Les lancements qui partagent une touche avec une commande de fenêtre
        // sont signalés eux aussi.
        let shared = ShortcutConflictEngine.conflictGroups([launch, leftHalf])
        assert(shared.count == 1)
        assert(shared[0].winner.id == "launch.com.example.app")

        print("Shortcut conflict checks passed")
    }
}
