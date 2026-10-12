# Vendors — copies locales de référence

## Inventaire vérifié le 2026-10-12

| Dossier | Amont | Contenu / licence |
|---|---|---|
| `rooms/` | https://github.com/saragordic/rooms | Sources MIT ; snapshot existant identique au HEAD `c659cc223f7b54b5a4d71ce859fb98d413af632c`. Priorité d'intégration. |
| `ClickFitMac/` | https://github.com/mertogzhn/ClickFitMac | README seulement, **pas de code publié** ; présentation de https://clickfitapp.com/#pricing. |
| `Reef/` | https://github.com/gouwsxander/Reef | Sources MIT, cycle de fenêtres par app et profils ; https://getreef.app. |
| `switch/` | https://github.com/Sanyam-G/switch | Sources **FSL-1.1-MIT**, référence locale uniquement à ce stade ; https://switch-dev.sanyamgarg.com/. |
| `references/moom.md` | https://manytricks.com/moom/ | Fiche de fonctionnalités, pas de code propriétaire. |
| `references/snapback.md` | https://snapbackapp.com | Fiche de fonctionnalités, pas de code propriétaire. |
| `references/ccccorners.md` | https://apps.apple.com/fr/app/ccccorners/id6754601983 | Fiche de fonctionnalités, pas de code propriétaire. |

SHA complets des nouveaux snapshots dans leurs `UPSTREAM.json`. Aucun `.git`
imbriqué ; les licences originales restent dans chaque dossier. Aucun de ces
dossiers n'est ajouté à la compilation de l'app.

**Analyse et ordre d'intégration :**
[`docs/window-management-inspirations.md`](../docs/window-management-inspirations.md).

## `rooms/` — Rooms by Sara Gordić

Copie locale d'archivage de l'application **Rooms** (gestionnaire de fenêtres macOS par
« rooms » — projets = ensembles de fenêtres + disposition), conservée ici comme référence
et source d'inspiration pour PKwindowsManagement, et au cas où l'amont disparaîtrait.

| Champ | Valeur |
|---|---|
| Upstream | https://github.com/saragordic/rooms |
| Commit cloné | `c659cc2` — « Keep My Layout when some of a room's windows are closed (#5) » |
| Date du clone | 2026-10-06 |
| Licence | MIT (voir `rooms/LICENSE`) — réutilisation autorisée avec attribution |
| Langue / cible | Swift, macOS 14+, Apple Silicon & Intel |
| Taille | ~4 500 lignes de Swift (Sources/RoomsCore + Sources/Rooms) |

### Architecture de la copie

- `Sources/RoomsCore/` — cœur pur et réutilisable (géométrie, layouts, matching,
  stockage JSON) : `Layout.swift` (moteur Tiler), `GridLayout.swift`, `Snap.swift`,
  `Matcher.swift`, `Room.swift`, `WindowSlot.swift`, `Arrangement.swift`,
  `Geometry.swift`, `Templates.swift`, `RoomStore.swift`.
- `Sources/Rooms/` — couche AppKit : `Windows/WindowEngine.swift` (parking, inventory,
  AX), `Palette/` (switcher ⌥Space), `Picker/` (sélection des fenêtres d'une room),
  `Overlay/` (preview de layout, toast, welcome), `AppDelegate.swift`, `Hotkey.swift`.
- `Tests/` — tests unitaires du moteur de layout (`make test`).
- `docs/` — documentation amont.

### Mettre à jour la copie

Cloner l'amont dans un dossier temporaire, noter le SHA complet et comparer son
`git archive HEAD` au snapshot suivi. Examiner le diff avant remplacement ;
préserver les licences, les modifications locales et la provenance. Ne pas
supprimer le dossier existant ni créer un dépôt Git imbriqué pour une mise à jour.

### Analyse comparative

Voir [`../docs/rooms-gap-analysis.md`](../docs/rooms-gap-analysis.md) : écarts
PKwindowsManagement ↔ Rooms et pistes d'intégration.
