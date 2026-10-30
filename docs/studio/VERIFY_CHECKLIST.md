# VERIFY CHECKLIST — Refonte Atelier Glass & Modes Libre / Tiling / Strip / Rooms

- [ ] `PKStudioDesignSystem.swift` fournit les tokens et composants Atelier Glass partagés
- [ ] `WorkspaceWindowMode` (`.free`, `.tiling`, `.strip`) fonctionne écran par écran et conserve `preferredTilingLayout`
- [ ] `RoomWindow.savedFrame` (`RoomNormalizedRect`), `Room.useSavedFrames` et `Room.handoffPolicy` sont persistés, rétrocompatibles et testés
- [ ] Capture en 1 clic des positions actuelles des fenêtres d'un écran dans une Room (`captureCurrentWindows`)
- [ ] Réglages → **Fenêtres** : cartes d'écrans visuelles, cartes de modes Libre/Tiling/Strip, galerie visuelle des 7 layouts, studio Strip et curseurs de marges visuels
- [ ] Réglages → **CMD+Tab** : studio visuel dédié avec aperçu interactif en direct et cartes illustrées
- [ ] Réglages → **Rooms** & Éditeur : scène visuelle avec positions enregistrées vs layout dynamique et politique Conserver / Adopter
- [ ] **Spotlight** (`CompactLaunchpadView`) : recherche unifiée incluant Apps, Rooms, Modes de fenêtres (Libre/Tiling/Strip), Snippets et Calculatrice
- [ ] **Rooms Switcher** (`⌃⌥R`) & **CMD+Tab** (`⌃⌥Tab` / `⌘Tab`) : barre de mode Libre/Tiling/Strip intégrée et habillage Atelier Glass
- [ ] Tests unitaires existants + `WorkspaceModeAndRoomSceneChecks` passent
- [ ] Build SwiftPM complet (`MacOSX26.5.sdk`) réussit sans erreur
- [ ] `plutil -lint` passe sur FR/EN/ES/DE et `git diff --check` est propre
