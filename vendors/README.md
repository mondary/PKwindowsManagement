# Vendors — copies locales de référence

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

```bash
rm -rf vendors/rooms
git clone --depth 1 https://github.com/saragordic/rooms.git vendors/rooms
rm -rf vendors/rooms/.git   # garder la copie trackée dans notre dépôt
# puis mettre à jour le commit cloné dans ce tableau et le CHANGELOG
```

### Analyse comparative

Voir [`../docs/rooms-gap-analysis.md`](../docs/rooms-gap-analysis.md) : écarts
PKwindowsManagement ↔ Rooms et pistes d'intégration.
