# VERIFY CHECKLIST — Modes Libre/Tiling

## Fonctionnel

- [ ] Le mode/layout est distinct par écran + Space et persiste après relance.
- [ ] Le menu bascule le mode du Space courant; les Réglages modifient le layout du bon workspace.
- [ ] Toutes les familles sont proposées en permanence, de 1 fenêtre à 64+.
- [ ] Une nouvelle fenêtre standard rejoint le tiler; une fermeture retire seulement cette fenêtre.
- [ ] Libre laisse les fenêtres libres; Room applique son layout initial sans changer sa sauvegarde.
- [ ] Après ouverture d'une Room en Tiling, le tiler du Space reprend les fenêtres une seule fois.
- [ ] Canvas conserve scroll horizontal/vertical, minimap, paires, reprise après Space et restore exact.
- [ ] Tiling → Libre et arrêt de l'app restaurent chaque cadre initial; recovery reprend après kill simulé.
- [ ] Aucun conflit entre RoomEngine, Canvas et TilingService; aucun mouvement inter-Space.

## Layouts et preview

- [ ] Auto choisit une géométrie confortable et indique le résultat dans le preview.
- [ ] Focus, Colonnes, Grille, Stack, Dwindle et Monocle ont des règles d'arrivée de fenêtre distinctes.
- [ ] Canvas est visuellement identifié comme strip défilant avec viewport/minimap.
- [ ] Chaque preview anime les arrivées 1→6; toutes les fenêtres sont fictives/numérotées.
- [ ] Seule la preview active s'anime; réduire les animations donne un état statique clair.
- [ ] Boutons play/pause/replay, navigation clavier et VoiceOver fonctionnent.

## Robustesse

- [ ] Pas d'autorisation AX : aucun déplacement, explication visible.
- [ ] Fenêtres fullscreen, modales, minimisées, multi-Space et non redimensionnables exclues proprement.
- [ ] Test écran débranché/reconnecté, Space change en cours de placement et app AX qui répond lentement.
- [ ] Test de fenêtre de l'app elle-même : pas d'appel AppKit/AX local depuis le worker.
- [ ] Les Rooms Codable existantes (Auto, Focus, Columns, Grid, Stack, Dwindle, Monocle) se chargent sans perte.

## Résultats automatisés exécutés

- [x] `TilingLayoutChecks` : huit choix, géométrie 1–6 fenêtres, profil isolé par écran/Space et résultat Auto visible.
- [x] `RoomTilerChecks` et `CanvasStateChecks` : géométrie Room et politiques de workspace/journal existantes.
- [x] Analyse syntaxique Swift, lint des quatre localisations et `git diff --check`.

## Qualité / livraison locale

- [ ] Tests worker/AX, restauration réelle, cycle de vie Room/Space et QA native passent.
- [ ] Build Dev officiel réussi; app remplacée, relancée, version Dev contrôlée.
- [ ] Preview vérifiée visuellement dans Réglages, thème clair/sombre et mouvement réduit.
- [ ] `.strings` FR/EN/ES/DE passent `plutil -lint`.
- [ ] CHANGELOG/README FR/EN synchronisés; screenshots d'UI concernés réévalués.
- [ ] `git diff --check` propre; statut git et commit revus.
