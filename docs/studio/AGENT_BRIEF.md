# AGENT BRIEF — Refonte Atelier Glass, Studio Réglages & Modes Libre / Tiling / Strip / Rooms

## Mission

Implémenter la spécification `docs/studio/SPEC.md` dans `Macos_PKwindowsManagement` :
1. Créer le design system partagé `PKStudioDesignSystem.swift` (Atelier Glass).
2. Étendre le moteur de fenêtres (`TilingLayout.swift`, `HorizontalCanvasService.swift`) pour exposer les 3 modes explicites **Libre / Tiling / Strip (OpenCanvas)** écran par écran (`displayWorkspaces`).
3. Étendre le moteur de Rooms (`RoomModels.swift`, `RoomEngine.swift`, `RoomLayoutDiagram.swift`) avec la capture et la restauration de positions enregistrées (`RoomNormalizedRect`, `useSavedFrames`, `handoffPolicy`), ainsi que la bascule directe vers Libre / Tiling / Strip.
4. Refondre les Réglages (`PKwindowsManagementApp.swift`, `WindowShortcutsPreferencesView.swift`, `WindowSwitcherSettingsView.swift`, `RoomsPreferencesView.swift`) en studios visuels sans « mode texte ».
5. Harmoniser les 4 surfaces d'overlay (`CompactLaunchpadView.swift`, `LaunchpadOverlayView.swift`, `RoomsSwitcherView.swift`, `WindowSwitcherView.swift`) avec Atelier Glass et les actions de modes/Rooms.

## Contraintes

- Stack : Swift 5, AppKit, SwiftUI, Accessibility API ; zéro dépendance externe.
- Compatibilité ascendante stricte pour `rooms.json` et les backups de réglages.
- Tous les appels AX locaux sur le thread principal via `CanvasWindowAccess.onAccessibilityThread`, le worker Canvas restant propriétaire séquentiel du strip.
- Bump CalVer dans `CHANGELOG.md`, `README.md`, `README_en.md`.

## Commandes obligatoires de verify

- `swiftc` checks pour toutes les suites `Tests/*Checks.swift` (dont la nouvelle suite `Tests/WorkspaceModeAndRoomSceneChecks.swift`)
- `MACOSX_DEPLOYMENT_TARGET=13.0 swift build -c debug --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk --build-system native`
- `plutil -lint src/macos/Resources/*.lproj/Localizable.strings`
- `git diff --check`
