# SPEC — Refonte Atelier Glass, Studio Réglages & Modes Libre / Tiling / Strip / Rooms

## Goal

Unifier l'esthétique de PKwindowsManagement (Launcher, Spotlight, Rooms, CMD+Tab et Réglages) autour du design system **Atelier Glass**, remplacer tous les réglages « mode texte » par des studios visuels avec aperçus en direct, et offrir un jonglage fluide écran par écran entre **Mode Libre**, **Mode Tiling**, **Mode Strip (OpenCanvas / OmniWM)** et **Rooms** (avec capture et restauration des positions exactes des fenêtres).

## Non-goals

- Aucune dépendance externe UI (100 % SwiftUI + AppKit natif).
- Aucune rupture de compatibilité avec `rooms.json` existant ni avec les sauvegardes de réglages v1 à v14.
- Aucun déplacement forcé de fenêtres entre Spaces macOS distincts.

## Scenarios (Gherkin)

### Scenario 1 — Jongler entre Libre, Tiling et Strip écran par écran
Given un ou plusieurs écrans connectés
When l'utilisateur choisit **Libre**, **Tiling** ou **Strip (OpenCanvas)** sur la carte d'un écran (dans Réglages → Fenêtres, le menu de barre de menus, Spotlight, Rooms ou CMD+Tab)
Then le profil `(displayUUID, spaceID)` de cet écran bascule immédiatement dans ce mode sans altérer les autres écrans, et le retour en **Libre** restaure les cadres d'origine.

### Scenario 2 — Rooms avec positionnement des fenêtres enregistré
Given des fenêtres disposées librement ou selon un projet sur un écran
When l'utilisateur crée ou met à jour une Room avec **Capturer les positions actuelles** (dans Réglages → Rooms, l'éditeur de Room ou le panneau `⌃⌥R`)
Then chaque fenêtre de la Room enregistre son cadre normalisé (`x, y, width, height` sur la zone visible de l'écran) et l'activation de la Room restaure exactement ce positionnement.

### Scenario 3 — Politique Room : Conserver les positions ou Adopter le mode de l'écran
Given une Room activée sur un écran
When la Room est configurée en **Conserver le positionnement de la Room**
Then l'écran passe/reste en mode Libre avec les positions exactes de la Room sans qu'un tiler automatique ne les écrase.
When la Room est configurée en **Adopter le mode de l'écran**
Then la Room applique son placement initial puis laisse le Tiling ou le Strip actif reprendre la main.

### Scenario 4 — Réglages 100 % visuels (zéro mode texte)
Given l'utilisateur ouvre la fenêtre de Réglages (`⌘,`) sur **Fenêtres**, **CMD+Tab**, **Rooms**, **Launchpad** ou **Apparence**
When il ajuste le mode d'un écran, le layout Tiling, le Strip, le comportement `⌘Tab` ou les marges
Then chaque option est présentée sous forme de carte illustrée, galerie de miniatures ou curseur avec aperçu en direct, sans bloc de paragraphes techniques.

### Scenario 5 — Spotlight unifié (Apps, Rooms, Modes, Fenêtres, Snippets, Calculatrice)
Given l'utilisateur ouvre le Launchpad en mode **Compact (Spotlight)** (`⌥Espace`)
When il tape une requête ou parcourt les filtres (`Tout`, `Apps`, `Rooms & Modes`, `Snippets`)
Then il peut lancer une application, activer une Room enregistrée, basculer l'écran en mode **Libre / Tiling / Strip**, ou exécuter un snippet.

## Edge cases (must-pass)

### Validation & Migration
- Les fichiers `rooms.json` existants (sans `savedFrame`, `useSavedFrames` ni `handoffPolicy`) se décodent sans perte avec des valeurs par défaut sûres.
- Les sauvegardes de réglages `v1` à `v15` sont supportées ; `TilingWorkspaceProfile` expose `workspaceMode` (`.free`, `.tiling`, `.strip`) tout en préservant le codage `mode` + `layout` (`mode == .tiling && layout == .canvas` ⇔ `.strip`).

### Permissions & Accessibilité
- Sans permission Accessibilité, aucun déplacement de fenêtre n'est tenté et une carte d'état visuelle propose l'ouverture des Réglages Système.
- Sans permission Enregistrement de l'écran, CMD+Tab affiche les icônes et titres des fenêtres avec un bouton visuel d'autorisation.

### Multi-écrans & Cycle de vie
- Si l'écran cible d'une Room est débranché, ses cadres normalisés (`0...1`) s'adaptent automatiquement à la zone visible de l'écran de repli (écran sous le pointeur).
- Changer le mode de l'Écran 1 ne modifie ni le profil ni les fenêtres de l'Écran 2.

## Acceptance Criteria

1. `WorkspaceWindowMode` (`.free`, `.tiling`, `.strip`) est sélectionnable par écran connecté et mémorisé par `(displayUUID, spaceID)` avec `preferredTilingLayout` conservé lors du passage en `.strip`.
2. `RoomWindow` supporte `savedFrame: RoomNormalizedRect?` et `Room` supporte `useSavedFrames: Bool` et `handoffPolicy: RoomHandoffPolicy` (`.keepRoomPositions`, `.adoptWorkspaceMode`), avec capture en un clic des fenêtres ouvertes de l'écran.
3. La page **Fenêtres** des Réglages présente des cartes d'écrans visuelles, trois cartes de mode (**Libre**, **Tiling**, **Strip**), une galerie visuelle des 7 layouts Tiling, un studio Strip et des curseurs visuels de marges avec aperçu.
4. Une section dédiée **CMD+Tab** (`⌘Tab`) dans la sidebar des Réglages (et sa carte dans Fenêtres) présente un aperçu interactif en direct du sélecteur et des cartes visuelles pour chaque réglage.
5. Les 4 surfaces d'overlay (Launchpad plein écran, Spotlight compact, Rooms `⌃⌥R`, CMD+Tab `⌃⌥Tab`/`⌘Tab`) partagent les tokens **Atelier Glass** (`PKStudioDesignSystem`) et permettent de jongler entre Rooms et modes Libre/Tiling/Strip.
6. Toutes les suites de tests existantes et les nouveaux tests (`WorkspaceModeAndRoomSceneChecks`) compilent et passent à 100 %.

## UI Contract

- **Design system** : `PKStudioDesignSystem` (Atelier Glass — matériaux translucides calibrés, bordures 1 px lumineuses, coins continus 12/16/22 pt, accents sémantiques par mode : Libre = Indigo/Slate, Tiling = Cobalt, Strip = Teal/Cyan, Rooms = Violet/Ambre).
- **États obligatoires** : aperçu actif, état vide illustré, permission manquante avec action directe, sélection clavier visible.
- **Accessibilité** : respect de `accessibilityReduceMotion`, navigation complète au clavier, contrastes lisibles en mode Clair et Sombre, localisations FR/EN/ES/DE valides (`plutil -lint`).

## Definition of Done

- Build complet `swift build` (SDK 26.5) sans erreur.
- Toutes les suites de tests unitaires et géométriques passent.
- Fichiers `.strings` FR/EN/ES/DE validés par `plutil -lint`.
- `CHANGELOG.md`, `README.md` et `README_en.md` synchronisés avec bump CalVer.
- `git diff --check` propre.
