# SPEC — Modes Libre et Tiling continu

## Goal

Ajouter un vrai mode de tiling continu, choisi par écran et Space macOS, avec des règles de placement qui restent actives quand des fenêtres sont ajoutées; conserver le mode Libre et fournir des previews animées pédagogiques dans Réglages → Fenêtres.

## Décisions confirmées

- Deux modes : **Libre** et **Tiling**.
- État et layout persistés par paire écran + Space macOS.
- Bascule du mode dans Réglages et depuis le menu de la barre de menus.
- En Libre, les Rooms gardent leur fonctionnement actuel : placement initial selon le layout enregistré, puis fenêtres libres.
- En Tiling, l'activation d'une Room applique son placement initial, puis le layout persistant du Space prend le relais pour les fenêtres présentes et futures. Le layout enregistré dans la Room n'est pas modifié.
- Le Canvas horizontal existant devient un layout du moteur Tiling; son scroll, sa restauration et sa minimap sont conservés. Un seul moteur possède une fenêtre à la fois.
- Aucune option n'est masquée en fonction du nombre de fenêtres. Les previews montrent aussi l'évolution à l'arrivée de fenêtres futures.
- Les previews sont dans les Réglages du tiler, pas dans les sélecteurs de Room.

## Layouts persistants

Tous les choix restent disponibles quel que soit l'inventaire courant. Les familles gardées sont fondées sur des règles d'insertion/placement différentes, et non sur le résultat géométrique d'un nombre précis de fenêtres :

1. **Auto** — choisit une disposition confortable pour la taille d'écran et le nombre de fenêtres.
2. **Focus** — fenêtre principale dominante, fenêtres secondaires organisées à côté.
3. **Colonnes** — fenêtres réparties en colonnes selon la règle dédiée.
4. **Grille** — cellules équilibrées en lignes et colonnes.
5. **Stack / Deck** — zone principale et fenêtres secondaires superposées, leurs barres de titre restant accessibles.
6. **Dwindle** — partitions récursives alternées; chaque nouvelle fenêtre subdivise la zone restante.
7. **Monocle** — une fenêtre visible; les autres fenêtres du groupe restent récupérables et peuvent redevenir actives.
8. **Canvas** — grille/strip horizontal existant, défilement continu et minimap conservés.

Auto est une politique d'adaptation, pas une géométrie fixe. Les autres layouts ont des comportements d'ajout distincts; aucune déduplication dépendante du nombre courant n'est faite.

## Scénarios

### Mode Tiling continu

Given un Space configuré en Tiling avec un layout choisi
When une fenêtre standard compatible apparaît sur cet écran et ce Space
Then elle est intégrée au layout actif et les fenêtres gérées sont redisposées selon cette règle.

### Mode Libre

Given un Space en Libre
When une fenêtre apparaît ou que l'utilisateur la déplace
Then le service ne reprend pas sa géométrie. Une Room activée fournit seulement son placement initial.

### Room en Tiling

Given un Space en Tiling
When une Room est activée
Then sa disposition sauvegardée est appliquée comme placement initial; ensuite le tiler du Space devient propriétaire des fenêtres compatibles, sans modifier les données sauvegardées de la Room.

### Toggle / restauration

Given des fenêtres gérées et leur journal de géométrie d'origine
When l'utilisateur passe de Tiling à Libre ou quitte proprement l'app
Then les fenêtres gérées sont restaurées à leur position et taille d'origine, avec reprise sûre après arrêt inattendu.

### Space ou écran inactif

Given un Space géré qui devient temporairement inactif, ou un écran déconnecté
When la topologie change
Then l'état du Space est suspendu/repris sans mélanger les fenêtres; un écran définitivement déconnecté suit le chemin de restauration existant.

### Preview pédagogique

Given Réglages → Fenêtres
When l'utilisateur sélectionne un layout
Then un aperçu montre les fenêtres 1 à 6 arrivant successivement, leur destination et une explication simple de la règle; tous les layouts restent présents.

## Edge cases must-pass

### Permissions et fenêtres

- Sans Accessibilité, ne pas déplacer de fenêtres; expliquer l'autorisation nécessaire.
- Fenêtres modales, fullscreen, minimisées, multi-Space, non redimensionnables ou inaccessibles suivent des exclusions explicites et n'empêchent pas les autres fenêtres d'être gérées.
- Découverte d'une fenêtre nouvelle ou fermeture pendant une animation de Space ne doit ni créer de doublon ni perdre le journal.
- Les fenêtres de l'app elle-même gardent les appels AppKit/AX locaux sur le thread principal.

### Cycle de vie

- Toggle Libre/Tiling répété, changement de Space, changement d'écran, écran débranché et extinction de l'app ne doivent pas laisser des fenêtres parquées.
- Une Room activée ne doit pas être redisposée en parallèle par RoomEngine et le moteur Tiling.
- Les anciennes Rooms et leurs valeurs de layout doivent continuer à se décoder sans migration destructive.

### Réglages et previews

- Les préférences sauvegardées/restaurées incluent le mode/layout par workspace sans remplacer un réglage d'un autre écran/Space.
- Les previews restent compréhensibles pour 1 à 6 fenêtres, ainsi qu'avec « Réduire les animations » activé.

## UI Contract

- Stack : Swift + AppKit, vues de réglage et previews en SwiftUI; aucune dépendance externe.
- Source de géométrie : même moteur pur utilisé par le placement réel et les previews.
- Navigation : commandes existantes de Réglages/menu, libellés localisés FR/EN/ES/DE, clavier et labels VoiceOver.
- Animation : uniquement la preview sélectionnée progresse; mouvement réduit respecté, bouton de lecture/reprise accessible.
- Les previews utilisent des fenêtres fictives numérotées, jamais titres ou contenus personnels.

## Acceptance criteria

1. Le mode Tiling et le layout sont mémorisés séparément par écran + Space; le menu permet de basculer le Space courant.
2. En Tiling, les fenêtres standard découvertes ultérieurement rejoignent le layout actif; en Libre, elles ne sont pas reprises par le service.
3. Les huit choix (Auto, Focus, Colonnes, Grille, Stack, Dwindle, Monocle, Canvas) sont toujours présentés, quel que soit le nombre courant de fenêtres.
4. Rooms gardent leur layout enregistré et leur comportement initial en Libre; en Tiling, le layout du Space prend le relais après l'activation.
5. Les previews animées des Réglages montrent une séquence d'ajouts de fenêtres pour chacun des huit choix et décrivent leur comportement en langage simple.
6. Le Canvas conserve scroll, minimap, reprise au retour sur le Space et restauration exacte; aucune fenêtre n'est pilotée par deux services.
7. Le passage à Libre restaure les cadres d'origine et un arrêt inattendu reprend le journal sans déplacer une fenêtre vers un autre Space.
8. Les tests de géométrie, insertion/fermeture, sélection workspace, restauration, permissions et accessibilité passent; le build Dev compile et se lance.

## Definition of Done

- Acceptance criteria 1–8 validés.
- Tests standalone et tests du projet passés.
- Build Dev officiel installé et relancé; version Dev confirmée.
- Vérification visuelle des previews dans l'app réelle, états clair/sombre et réduction des animations.
- READMEs FR/EN et CHANGELOG synchronisés; `git diff --check` propre.
