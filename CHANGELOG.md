# Changelog

## [2026.09.03] - 2026-09-03
### Added
- `Tout maximiser` : toutes les fenêtres visibles (non réduites) de tous les écrans passent en presque maximisé via `Ctrl + Option + G` (personnalisable dans les réglages), chaque fenêtre restant restaurable via l'action Restaurer

## [2026.09.02] - 2026-09-02
### Fixed
- La marge générale ne se cumule plus entre zones de snap adjacentes : un bord d'écran compte plein, un bord intérieur compte à moitié — le gap total vaut une seule fois la marge (1%), partout

## [2026.09.01] - 2026-09-02
### Fixed
- Le launcher s'affiche sur l'écran où se trouve la souris même quand son panneau est réutilisé depuis le cache (régression du launcher instantané)
- Le launcher plein écran recouvre à nouveau tout l'écran externe (plus de marge en haut ni à droite) et la grille par écran suit l'écran affiché
- Le mode compact se recentre sur l'écran cible à chaque ouverture
- Les réglages s'ouvrent à nouveau même quand la fenêtre du dashboard est fermée ou non restaurée : l'ouverture ne dépend plus d'une closure SwiftUI capturée à l'affichage, la fenêtre est mise au premier plan ou recréée via l'Apple Event `reopen`

## [2026.08.27] - 2026-08-14
### Added
- Personnalisation de l'apparence Big Year : anniversaires ou noms des mois en gras au choix (le `!` reste prioritaire) et sélecteurs de couleur pour chaque élément (fond, jours fériés, anniversaires, événements, zones, texte…)
- Réinitialisation des couleurs personnalisées d'un clic

## [2026.08.26] - 2026-08-14
### Added
- Thème `Poster bleu` inspiré des calendriers muraux : 12 mois en lignes, 31 jours en colonnes, typographie bleue et aplats francs
- Clic sur une journée pour ajouter directement un événement ponctuel ou une plage, récurrente ou limitée à ses années
- Connexion native aux calendriers macOS, dont Google Calendar, via EventKit pour afficher les événements journée entière

### Fixed
- `Échap` ferme Big Year même si l'éditeur est focalisé ou si le panneau flottant n'est plus l'application active
- Les plages datées traversant le nouvel an conservent correctement leur année de début et de fin

## [2026.08.25] - 2026-08-14
### Added
- Événements personnalisés Big Year : un jour (`JJ.MM,Label`) ou une plage (`JJ.MM-JJ.MM,Label`), année optionnelle (`JJ.MM.AAAA`) et marqueur `!` pour gras
- Les plages dont la fin précède le début traversent le nouvel an (ex : `28.12-03.01`)
- Les événements apparaissent en bandes dans la grille, teintent leurs journées, s'ajoutent à la légende et au survol, avec éditeur dédié dans les réglages et le panneau d'options

## [2026.08.24] - 2026-08-14
### Fixed
- Les raccourcis globaux ne capturent plus `Entrée`, les flèches ni la saisie lorsque PKwindowsManagement est au premier plan
- L’éditeur d’anniversaires accepte de nouveau la souris, les déplacements du curseur et les sauts de ligne natifs
- La barre d’année utilise entièrement la couleur du thème et n’affiche plus de bande blanche inférieure

## [2026.08.23] - 2026-08-14
### Changed
- La liste des anniversaires utilise un éditeur AppKit natif plus grand dans les réglages Big Year

### Fixed
- Les flèches déplacent correctement le curseur dans les anniversaires sans perte de focus lors des mises à jour
- L’éditeur conserve la sélection, l’undo, le scroll et désactive les corrections orthographiques rouges

## [2026.08.22] - 2026-08-14
### Changed
- L’aperçu Big Year passe sous les contrôles et occupe toute la hauteur restante de sa page de réglages

## [2026.08.21] - 2026-08-14
### Added
- La section de réglages Big Year affiche un aperçu vivant du calendrier courant

### Changed
- L’aperçu réagit immédiatement au thème, à la zone scolaire et aux anniversaires configurés

## [2026.08.20] - 2026-08-14
### Changed
- Big Year dispose de sa propre section dans la sidebar des réglages
- Thème, zone scolaire et anniversaires quittent Général pour une page dédiée sans changement de configuration

## [2026.08.19] - 2026-08-14
### Added
- Les paramètres généraux exposent toutes les options Big Year : thème avec palettes, zone scolaire et liste des anniversaires

### Changed
- Les réglages Big Year du calendrier et des paramètres généraux restent synchronisés via la même configuration persistante

## [2026.08.18] - 2026-08-14
### Changed
- Le champ anniversaires reçoit automatiquement le focus à l’ouverture des options et accepte immédiatement la navigation aux flèches
- `Cmd + E` ouvre les options Big Year directement au clavier

### Fixed
- Catppuccin Mocha utilise un texte sombre dédié sur les barres pastel et ne subit plus l’apparence AppKit claire forcée

## [2026.08.17] - 2026-08-14
### Changed
- La barre supérieure de Big Year est entièrement peinte avec le thème actif, sans bandes blanches au-dessus ni au-dessous
- Le choix du thème devient une liste alignée à gauche avec quatre pastilles de prévisualisation pour chaque palette

## [2026.08.16] - 2026-08-14
### Added
- Thèmes Big Year : Pastel clair, Catppuccin Latte, Catppuccin Mocha et Dracula
- Marqueur `!` devant un prénom pour afficher un anniversaire important en gras

### Changed
- Les anniversaires utilisent désormais le format jour-mois `JJ.MM,Prénom` ou compact `JJMM,Prénom`, sans année
- Les anniversaires importants renforcent aussi la couleur de leur journée dans la grille

### Fixed
- Le raccourci global du launcher est réenregistré après la stabilisation du démarrage macOS

## [2026.08.15] - 2026-08-14
### Added
- Big Year affiche les week-ends, jours fériés français, vacances scolaires de la zone A/B/C choisie et anniversaires saisis à raison d'une entrée `MM-JJ,Prénom` par ligne
- Raccourcis `Ctrl + Option + =` et `Ctrl + Option + -` pour agrandir ou réduire la fenêtre depuis son centre

### Changed
- Big Year adopte une grille annuelle plein écran sans scroll, un thème clair pastel, une journée courante renforcée et un panneau latéral pour la zone scolaire et les anniversaires
- Le launcher précharge son catalogue hors du thread principal et conserve son panneau entre les ouvertures

### Fixed
- Les services globaux démarrent même lorsque macOS ne restaure pas la fenêtre Réglages
- Le launcher et Big Year restent accessibles après fermeture des Réglages; les actions du menu ont désormais une cible explicite
- `Échap` ferme Big Year directement au niveau de sa fenêtre

## [2026.08.10] - 2026-08-04
### Added
- Compact Launchpad themes: Light, Dark, Catpuccin, Glass — selectable in Settings → Launchpad when Style is Compact
### Fixed
- Light theme text now readable: black text on light gray background instead of white on white

## [2026.08.09] - 2026-08-04
### Added
- Compact Launchpad mode: Spotlight-style centered window (600×460) instead of fullscreen grid, with search, keyboard navigation (↑↓ enter esc) and calculator; switchable via the Style picker in Settings → Launchpad and persisted
- About section in Settings: app icon, version, description, GitHub links, license and macOS version
- Resizable left sidebar in Settings (default 210px, 170–320px range) with drag handle and resize cursor
- Resizable Snippets/URLs left pane (default 380px, 260–520px range) with drag handle and resize cursor
### Fixed
- Snippets/URLs layout no longer overflows: content now fills available height instead of shifting when the list grows
- Resizable split drag no longer jumps: drag start width is captured instead of accumulating translation

## [2026.08.08] - 2026-08-04
### Changed
- Restructured the project layout: sources moved to `src/macos/` (room for future `src/linux/`), scripts moved to `src/script/`, build artifacts and packaged app moved from `dist/` + `.build/` into `release/` (via `--scratch-path release/build`)
- Removed the GPL-3 `LaunchNext` reference submodule and the cleanroom note — the app is now 100% independent, no external code references
- `Resources/` root folder (empty localization vestige) removed; real localizations stay in `src/macos/Resources/`
- Scripts now compute the project root two levels up; `.gitignore` updated for `release/`
### Added
- `src/script/`, `src/macos/` directory structure; `src/linux/` placeholder intent
### Removed
- `submodules/LaunchNext`, `CLEANROOM.md`, `Resources/`, `dist/`, `.build/`

## [2026.08.07] - 2026-08-04 🔥
### Fixed
- **Window management now works on Electron apps (Chrome, VS Code, Slack, etc.)** — the root cause was `AXEnhancedUserInterface`: when enabled (default on Electron), these apps silently ignore AX frame changes. Now disabled before setting position/size, re-enabled after
- Window frame is now set in `size → position → size` order (was `position → size`), preventing macOS from rejecting moves when the window is too large for the destination screen
- Focused window lookup now uses `NSWorkspace.frontmostApplication` PID instead of `AXUIElementCreateSystemWide`, with fallback to `kAXWindowsAttribute[0]` — more reliable across all app types
- AX window operations deferred to next run-loop iteration instead of running synchronously inside the CGEvent tap callback (was causing silent failures on non-native apps)
### Changed
- Accessibility section in General settings now has "Re-request Access" and "Open System Settings" buttons for easier permission troubleshooting
### Added
- Localized strings for the new accessibility buttons (fr/de/es)

## [2026.08.06] - 2026-08-03
### Added
- New window actions: Maximize Height/Width, Move Up/Down/Left/Right, Restore, Reasonable Size, Make Larger/Smaller, Toggle Fullscreen, vertical Fourth columns (First/Second/Third/Last), First/Center/Last Two Thirds, First/Center/Last Three Fourths, Top/Bottom Third and Top/Bottom Two Thirds — all with icons and per-language labels
- New window actions are unbound by default (bind them in Settings → Windows)
### Changed
- Snapping core restored to the proven version from 2026.08.05; the new actions are layered additively on top, leaving the original geometry untouched
### Fixed
- Window management no longer broken: the earlier core rewrite made snapping fail for every app — reverted it and re-integrated the new actions additively
- Restore and Toggle Fullscreen remember the window's previous frame
- Removed dead `SimpleWindowManager` and unused SVG assets

## [2026.08.05] - 2026-08-03
### Added
- Window snapping service wired to global shortcuts (halves, quarters, thirds, sixths, fullscreen, center, almost-maximize, display cycling)
- Compact shortcut recorder with badge + Record/Stop and clear/reset per row; special keys (arrows, return, tab, space, delete) captured by keycode
- Per-preset margins (general / almost-full / center) as numeric fields, 1% default gap between windows
- True fraction icons for quarters, thirds, and sixths
- Launchpad overlay now shows the app version (bottom-right)
### Changed
- Migrated to CalVer versioning `YYYY.MM.PATCH` (pk-COMMIT convention)
- Default shortcuts: halves `⌃⌥Q/W/E/R`, quarters `⌃⌥Y/P/H/M`, sixths `⌃⌥U/I/O/J/K/L`
- Settings window sidebar toggle moved from system top-right to a left-placed button; custom 2-column layout replaces NavigationSplitView
- Window-shortcuts preferences use a responsive 2-column layout (1 column when narrow)
### Fixed
- Window snapping on external displays no longer jumps back to the MacBook (AX↔NSScreen coordinate flip corrected in screen detection)
- One-time migration resets stale window-shortcut overrides so new defaults apply

## [0.18] - 2026-06-16
### Added
- Menu bar now displays the app's official icon (full color) instead of a generic SF Symbol
- Settings sidebar header shows the official app icon alongside the app name
- Archive snippet available by default for every install, with a dedicated icon and a `Right Command + S` shortcut
- Archive keeps both files on name conflicts (Finder-style `file 2.ext`, `file 3.ext`)
- Archive moves Desktop items to a fast local archive first, then mirrors them to Google Drive in the background (throttled, non-blocking) — no more Mac freeze on large folders
### Changed
- Archive no longer overwrites or prompts on duplicate names
- Archive monthly folders now use deterministic French names (`2026_06_juin`) instead of relying on the process locale
- `DesktopArchive` now points to the Google Drive archive when detected, while keeping the fast local archive as the initial write target
### Fixed
- Duplicate Archive snippets (manual + default) collapsed into a single canonical entry, preserving the existing shortcut

## [0.17] - 2026-06-16
### Added
- Full-screen Big Year view from the menu bar menu
- Desktop app bundle creation documented in the README
### Changed
- Global shortcut startup and refresh now use a lightweight app catalog without loading all app icons
- Dominant icon color is computed only when the Launchpad sort mode is `Icon Color`
### Fixed
- Big Year overlay has safer close paths and less intrusive window behavior
- Timers, event taps, and global handlers are cleaned up more completely on shutdown

## [0.12] - 2026-06-04
### Added
- Left/right modifier key distinction for Command, Option, and Shift in launch shortcuts
- Fn + Shift modifier support for launch shortcuts
- Fine-grained Launchpad grid settings: icon size, column spacing, row spacing
- Top-aligned pages in horizontal navigation mode
- Accessibility status indicator card with grant-access button
- Automatic backup export to a user-chosen folder on every settings change
### Fixed
- Search bar text color now white on dark background in Launchpad overlay

## [0.10] - 2026-06-03
### Added
- Initial project scaffold
