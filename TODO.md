# TODO

## Launchpad
- [ ] Recherche globale type Spotlight.
- [ ] Apps installées affichées en grille.
- [ ] Récents remontés automatiquement.
- [ ] Commandes texte:
  - [x] `empty trash`
  - [x] `eject`
  - [ ] `calculator`
  - [ ] autres commandes système.
- [ ] Raccourcis visibles sur les tiles.
- [ ] Assignation de raccourcis par app.
- [ ] Filtres FR / EN.

## Raccourcis clavier avancés
- [ ] Modèle de profils de raccourcis.
- [ ] Enregistrement d’actions par app.
- [ ] Affichage du raccourci sur l’icône.
- [ ] Lancer une app directement au clavier.
- [ ] Raccourcis globaux configurables.

## Window Management
- [ ] Actions supplémentaires de snap.
- [ ] Multi-écran plus fin.
- [ ] Résolution des tailles relatives.
- [ ] Raccourcis avancés pour layouts.

## Rooms (inspiré de saragordic/rooms — voir docs/rooms-gap-analysis.md)
- [x] Moteur de layouts `RoomTiler` porté (Auto / Focus / Colonnes / Grille / Pile).
- [x] Vue Rooms façon Spotlight avec miniature du tiling par app, création depuis les apps actives, activation (lancement des apps manquantes + attente + tuilage) — hotkey ⌃⌥R (v1 : rooms par apps, pas par fenêtres individuelles).
- [x] Matching fenêtre à fenêtre (windowID → titre exact → titre similaire → autre fenêtre de l'app, fenêtres claimées évitées).
- [x] Écran cible par room : sélecteur à la création, badge dans la liste, repli sur l'écran du pointeur si débranché — Dev 2026.10.67.
- [x] Fermeture de room ⌘↓ (fenêtres minimisées, réactivation = retour) et activation directe ⌘1-9 dans le switcher — Dev 2026.10.67.
- [ ] Raccourcis directs ⌃⌥1-9 par room (globaux, hors switcher).
- [ ] Park & registre crash-safe (« Tout montrer »).
- [ ] Prototype room ↔ Space macOS dédié + wallpaper dédié.

## Inspirations
- [ ] Recherche Spotlight intégrée.
- [ ] Grids d’apps configurables.
- [ ] Gestion de profils de raccourcis.

## Product
- [ ] Refaire le README avec vision produit.
- [ ] Ajouter des captures d’écran.
- [ ] Préparer une roadmap versionnée.
