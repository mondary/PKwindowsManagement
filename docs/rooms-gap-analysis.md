# Analyse comparative — PKwindowsManagement ↔ Rooms

> Référence : copie locale [`vendors/rooms/`](../vendors/rooms/) (upstream
> https://github.com/saragordic/rooms, commit `c659cc2`, licence MIT).
> Rédigé le 2026-10-06.

## Ce qu'est Rooms — et ce qu'il n'est pas

Rooms est un petit gestionnaire de fenêtres (~4 500 lignes de Swift) construit autour
d'une seule idée : **un projet = une « room » = un ensemble de fenêtres + une
disposition**. On presse ⌥Space, on tape le nom de la room, les fenêtres du projet
reviennent disposées proprement, tout le reste se cache, et **rien n'est jamais fermé**.

Deux clarifications importantes par rapport à la perception initiale :

1. **Rooms ne gère PAS les bureaux virtuels macOS (Spaces).** Le README amont le dit
   explicitement : « Spaces and full-screen windows aren't managed; Rooms works with
   ordinary windows on the current Space ». Une « room » n'est pas un bureau dédié :
   c'est un jeu de fenêtres qui se rappelle sur l'écran courant, les autres étant
   masquées ou parquées hors écran.
2. **Rooms n'a PAS de wallpapers dédiés.** Aucune manipulation d'image de bureau nulle
   part dans les sources.

Ces deux features (Spaces dédiés + wallpaper par room) sont donc des idées qui vont
**au-delà** de Rooms — voir §« Notre différenciateur ».

### Comment on édite une room dans Rooms (la question restée sans réponse)

- **Revoir les fenêtres / l'ordre** : clic droit sur la room dans le switcher ⌥Space →
  **Edit Windows…** → cliquer une carte pour la retirer, re-cliquer pour la remettre en
  fin d'ordre ; la numérotation (1 = fenêtre principale) décide de la place dans le layout.
- **Changer le layout** : room sélectionnée dans ⌥Space → **Tab** (⇧Tab pour revenir) ;
  un aperçu animé défile tous les layouts qui tiennent sur l'écran, et la room retient
  celui qu'on choisit.
- **Arrangement à la main** : disposer les fenêtres soi-même (les raccourcis de snap
  aident) puis **⌘S** dans ⌥Space : Rooms reconnaît le layout le plus proche ou garde
  l'arrangement exact (« My Layout », recalé sur une grille 12 colonnes à gouttières
  régulières).
- **Renommer / supprimer** : clic droit aussi ; ⌘⌫ supprime, ⌘Z annule une suppression.
- **Édition brute** : `~/Library/Application Support/Rooms/rooms.json` est lisible et
  éditable à la main (menu → Edit Rooms…).

## Tableau comparatif

### ✅ Ce que nous avons en plus (à garder et à valoriser)

| Notre feature | État chez Rooms |
|---|---|
| Catalogue de snap riche : sixièmes, quarts, tiers, 2/3, 3/4, maximiser hauteur/largeur, agrandir/rétrécir, taille raisonnable, restore, plein écran | 16 actions seulement (moitiés avec cycle ½→⅔→⅓, quarts, tiers, 2/3, max, centre, écran suivant) |
| `Tout maximiser` (tous écrans) et `Tout maximiser (app active)` | N'existe pas |
| `Carreler toutes les fenêtres` (grille de l'app au premier plan) | N'existe pas hors room |
| Launchpad plein écran : recherche, récents, raccourcis par app, tri, grille configurable par écran | Pas de lanceur d'apps du tout |
| Raccourcis globaux par application | Non |
| Snippets (scripts exécutables + URLs) : Archive, DL2desk… | Non |
| Big Year (calendrier annuel thémé) | Non |
| Réglages SwiftUI complets + import/export JSON + auto-backup | Quasi aucun réglage : rooms.json édité à la main |
| Distinction modificateurs gauche/droite, Fn+Shift | Non |
| Marges de fenêtres configurables (presets) | Gap fixe 16 pt |
| FR/EN, i18n | Anglais uniquement |
| Mise à jour Homebrew + releases DMG | Équivalent (cask + releases) |

### ❌ Ce que Rooms a en plus (nos écarts)

| Feature Rooms | Détail | Effort d'intégration |
|---|---|---|
| **Rooms** : ensembles de fenêtres nommés par projet | Cœur de l'app : modèle `Room` (apps, fenêtres ordonnées, layout, aliases, raccourci direct), stocké en JSON éditable | **Moyen** — c'est LE chantier, mais RoomsCore est MIT et pur Swift |
| **Switcher ⌥Space** façon Spotlight | Recherche floue (préfixe, initiales, sous-séquence, aliases), récence, ⌘1-9, ⌘S, ⌘⌫, ⌘Z | Moyen — on a déjà un overlay Launchpad à recycler |
| **Moteur de layouts** | Auto / Focus / Stack / Columns / Grid / My Layout / As Saved, avec tailles minimales mesurées par app, fallback Stack, mémoire par écran | **Faible** — `Layout.swift`, `GridLayout.swift`, `Arrangement.swift` sont de la géométrie pure, copiables quasi tels quels |
| **Cycle ½ → ⅔ → ⅓** en repressant moitié gauche/droite | Comportement Rectangle, dans `Snap.swift` | **Très faible** |
| **Park & restore** | Les fenêtres hors room sont masquées ou parquées hors écran ; registre `resting.json` écrit AVANT tout déplacement (crash-safe) ; « Show Everything » | Moyen — `WindowEngine.swift` à adapter à notre AX |
| **Identité persistante des fenêtres** | Matching par windowID → titre exact → titre similaire → n'importe quelle fenêtre de l'app, en respectant les fenêtres « claimées » par d'autres rooms | Faible — `SlotMatcher` est pur Swift |
| **Lancement des apps manquantes** | Une room dont une app n'est pas lancée la démarre (`NSWorkspace.openApplication`) puis dispose | Faible — on a déjà `AppLauncherService` |
| **Aperçu de layout animé** | Overlay qui montre chaque layout en glissant quand on tape Tab | Moyen |
| **Layout par écran** | Laptop = Stack, moniteur = Focus, re-disposition auto quand un écran est branché | Moyen |
| **Gestion des pièges AX Electron/Chromium** | Bascule `AXManualAccessibility` à la lecture, park-avec-Finder, fenêtres d'apps masquées (subrole AXDialog) | Faible — portage direct de recettes |
| **Undo de suppression (⌘Z)** | La dernière room supprimée revient à sa place | Très faible |
| **Templates de rooms** | Suggère une description selon le nom ("design", "build"…) | Très faible |
| **Log des déplacements** | `~/Library/Logs/Rooms/rooms.log` | Trivial |

### ≈ Équivalences (mêmes features, implémentations différentes)

| Notion | Chez nous | Chez Rooms |
|---|---|---|
| Déplacement fenêtre | API d'accessibilité (AX) | API d'accessibilité (AX) |
| Snap moitiés/tiers/quarts/coins, écran suivant/précédent | ✓ (~50 actions) | ✓ (16 actions, gap 16 pt aligné sur le tiling) |
| Barre de menu | Icône + menu | Icône + menu |
| Permission Accessibilité | ✓ avec indicateur de statut | ✓ avec écran d'accueil |

## Ce qu'on peut intégrer rapidement (par ordre de rentabilité)

1. **Cycle ½→⅔→⅓ sur moitiés** (qq heures) : re-presser `Ctrl+Option+ H/L` enchaîne
   les largeurs. Code : `Snap.swift` (`step % 3`).
2. **Portage du moteur Tiler** (1-2 j) : intégrer `Layout.swift` + `GridLayout.swift` +
   `Arrangement.swift` + `Geometry.swift` (MIT, zéro dépendance AppKit) comme module
   `LayoutEngine` et s'en servir pour améliorer `Carreler toutes les fenêtres` :
   tailles minimales prises en compte, fallback Stack, choix Focus/Columns/Grid.
3. **Concept de Rooms minimal** (3-5 j) : modèle `Room` + stockage JSON + raccourcis
   directs ⌃⌥1-9 + application d'une room (disposer + masquer le reste via notre AX
   existant). Le switcher peut être un mode du Launchpad existant plutôt qu'une
   palette séparée dans un premier temps.
4. **Matching + lancement** : `SlotMatcher` + lancement des apps manquantes via
   `AppLauncherService` (déjà là).
5. **Park & ledger crash-safe** : adapter `WindowEngine` (parking hors écran +
   `resting.json` écrit avant tout mouvement + « Tout montrer »).
6. **Ensuite seulement** : aperçus animés, ⌘S « apprendre l'arrangement », layouts par
   écran, Edit Windows.

## Notre différenciateur (au-delà de Rooms)

Les deux envies qui ont motivé cette exploration n'existent pas chez Rooms :

- **Room ↔ bureau macOS dédié** : créer/associer un Space par room et y basculer en
  entrant dans la room. Faisable via AppleScript/System Events (navigation clavier
  Ctrl+←/→) ou API privées CGS — à prototyper avec prudence.
- **Wallpaper dédié par room** : changer l'image du bureau en entrant dans la room
  (`osascript` sur Desktop Pictures, ou `NSWorkspace.setDesktopImage`). macOS ne gère
  pas nativement un wallpaper par Space en mode propre, donc c'est un vrai terrain
  neuf où nous serions devant Rooms.

Scénario cible de l'utilisateur, reformulé : « toutes mes fenêtres de dev Chrome
auto-agencées en maximisant leur taille sur un bureau virtuel dédié, mes apps macOS
auto-agencées sur un autre bureau dédié, avec wallpaper dédié et switch rapide » —
aucune app du marché ne fait ce trio (tiling par projet + Space dédié + wallpaper).
C'est une direction produit crédible.

## Décision attendue

- [ ] Valider l'ordre d'intégration proposé (quick wins 1-2 d'abord, rooms ensuite)
- [ ] Trancher la question Spaces/wallpaper : prototype séparé ou intégré aux rooms ?
