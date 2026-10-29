# AGENT BRIEF — Modes Libre/Tiling

## Mission

Après validation GO SHIP, implémenter la SPEC `docs/tiling/SPEC.md` dans PKwindowsManagement : tiling continu par écran/Space, Canvas réutilisé comme layout, Room one-shot puis relais du tiler, et previews animées dans les Réglages.

## Contraintes

- Stack : Swift 5, AppKit, SwiftUI, Accessibility API; pas de dépendance tierce.
- Suivre les patterns thread/AX de `HorizontalCanvasService`, `CanvasWindowAccess`, `CanvasFrameApplication`, `SpaceManagementService`.
- Un seul propriétaire déplace une fenêtre; conserver journal, suspension par Space, restauration exacte et protection contre l'écran débranché.
- Réutiliser le code pur de `RoomTiler`/Canvas pour que previews et géométrie réelle restent alignées.
- Garder les valeurs Codable des Rooms et les données utilisateur existantes.
- Les choix ne dépendent jamais du nombre de fenêtres; les previews couvrent les ajouts futurs.
- Bump CalVer à chaque commit; CHANGELOG source de vérité; README FR/EN synchronisés; ne pas pousser ni créer de tag sans demande.

## Fichiers probables

- `src/macos/Services/HorizontalCanvasService.swift` et nouveaux modèles/services de tiling
- `src/macos/Services/Rooms/RoomTiler.swift`, `RoomEngine.swift`, `RoomModels.swift`
- `src/macos/AppSettings.swift`, `MenuBarController.swift`
- `src/macos/Views/Preferences/WindowShortcutsPreferencesView.swift` et vues de preview
- `src/macos/Resources/{fr,en,es,de}.lproj/Localizable.strings`
- `Tests/`, `.github/workflows/dev-build.yml`, `CHANGELOG.md`, `README.md`, `README_en.md`

## Interdit

- Ne pas copier le code de MangoWM; ne pas ajouter de fenêtres fictives au tiler réel.
- Ne pas masquer ou supprimer dynamiquement un layout selon l'inventaire courant.
- Ne pas changer le layout stocké d'une Room en activant le mode Tiling.
- Ne pas mélanger les IDs de Space ou déplacer une fenêtre vers un autre Space pour la rendre visible.
- Ne pas installer une build Stable, publier un feed, pousser ou taguer sans demande explicite.

## Verify obligatoire

- Tests standalone geometry/state/journal/Room + nouveaux tests de policy et preview.
- `swiftc -typecheck` ou build complet avec le toolchain Swift/Xcode disponible.
- `src/script/package_app.sh` en mode Dev, remplacement et relancement de l'app, version vérifiée.
- QA UI de la preview dans l'app réelle, mouvement réduit et clavier/VoiceOver.
- `plutil -lint` des quatre fichiers `.strings`; `git diff --check`.

## Sortie attendue

- Diff organisé, résultat des tests exact, limites des vérifications réelles explicites, commit PK avec bump CalVer.
