# Références de gestion de fenêtres — audit du 12 octobre 2026

## Sources effectivement récupérées

| Référence | Snapshot local | Réutilisation constatée |
|---|---|---|
| [Rooms](https://github.com/saragordic/rooms) | `vendors/rooms/`, `c659cc223f7b54b5a4d71ce859fb98d413af632c` ; identique au HEAD amont vérifié | MIT, copyright et licence à conserver. Priorité produit n°1. |
| [ClickFit](https://clickfitapp.com/#pricing) / [GitHub](https://github.com/mertogzhn/ClickFitMac) | `vendors/ClickFitMac/`, `97dd53721bee99f807d155e2ec4ca4b595616f43` | Dépôt de présentation : **un README uniquement**, aucun Swift ni licence de code. Les fonctionnalités sont à réimplémenter. |
| [Reef](https://getreef.app) / [GitHub](https://github.com/gouwsxander/Reef) | `vendors/Reef/`, `63bddb73858b3d34d1e8755f10158f310c515c60` | MIT, Xander Gouws et Omar Hayat. Code réutilisable avec attribution. |
| [Switch](https://switch-dev.sanyamgarg.com/) / [GitHub](https://github.com/Sanyam-G/switch) | `vendors/switch/`, `4cffdf72f233603663b50e6c0d709e118aacf9bc` | **FSL-1.1-MIT**, pas MIT actuel. Licence restrictive sur les usages commerciaux concurrents ; copie de référence locale, aucun code intégré à PK. Le README annonce la conversion MIT au 6 mai 2028 ; vérifier la date applicable à la version réutilisée. |
| [Moom](https://manytricks.com/moom/) | `vendors/references/moom.md` | Produit propriétaire : référence fonctionnelle, aucun code obtenu. |
| [Snapback](https://snapbackapp.com) | `vendors/references/snapback.md` | Produit propriétaire : référence fonctionnelle, aucun code obtenu. |
| [CCCCorners](https://apps.apple.com/fr/app/ccccorners/id6754601983) | `vendors/references/ccccorners.md` | Produit propriétaire : fiche de référence, aucun code obtenu. |

Les nouveaux snapshots Git contiennent un `UPSTREAM.json` (URL, SHA complet, date).
Ils n'ont pas de `.git` imbriqué et ne sont ni des sous-modules ni des dépendances du
build : `Package.swift` ne compile que `src/macos`. Aucun script vendor n'a été exécuté.
Les observations de sites sont des descriptions annoncées, pas des tests des apps.

## 1. Rooms — le chantier prioritaire

Déjà dans PK : sélection de fenêtres individuelles, matching ID/titre/app, cinq
layouts, ouverture des apps manquantes, écran cible par room, minimisation,
activation dans le switcher et accès visible depuis les réglages.

Les principaux écarts restants, avec points d'entrée réels dans le snapshot :

| Priorité | Intégration | Sources Rooms à adapter | Raccord PK / réception |
|---|---|---|---|
| P1 | **Modifier une room existante** : nom, fenêtres, ordre, écran | `Sources/Rooms/Picker/`, `Palette/`, `RoomsCore/RoomStore.swift` | Ajouter un mode édition à `RoomsSwitcherModel` qui garde l'ID ; annuler sans écriture, fenêtres fermées conservées comme slots. |
| P1 | **Ma disposition / enregistrer l'arrangement courant** | `RoomsCore/Arrangement.swift` (`read`), `GridLayout.swift`, `Room.swift` ; `WindowEngine.learn` | Étendre `RoomLayoutKind` et le Codable de `Room` avec géométries normalisées et écrans ; migration des rooms actuelles. Tester écran absent, fenêtres fermées et chevauchement volontaire. |
| P1 | **Basculer en room en rangeant les autres fenêtres**, puis « Tout montrer » | `WindowEngine.arrange`, `park`, `restoreEverything`, `recoverFromLastSession`, registre dans `Windows/` | Registre écrit avant déplacement ; propriétaire unique entre Canvas et Rooms. Ne jamais confondre minimisation, fermeture réelle et suppression de la définition. Tester crash, PID réutilisé, app arrêtée et bureau absent. |
| P2 | Layout adapté à l'écran et contraintes de taille vérifiées | `WindowEngine.plan`, `layoutChoices`, `relayout`, `measureMinimums`, `learnMinimums` | Unifier progressivement l'écriture AX et l'inventaire ; ne pas importer les sondes 1×1 qui feraient clignoter les fenêtres sans contexte contrôlé. |
| P2 | Annuler suppression et raccourcis globaux par room | `RoomStore.swift`, `Palette/`, `Hotkey.swift` | Undo et actions intégrées à notre catalogue configurable ; ne pas écraser les raccourcis de tiers/sixièmes de l'utilisateur. |

**Lien immédiat avec le bug Canvas :** `WindowEngine.swift` documente les tailles
AX transitoires pendant les animations et ignore une sonde qui n'a pas réduit la
fenêtre. La Dev 69 applique une négociation PK bornée et testée : taille avant
position basse, écritures répétées, lecture après délai ; l'ancienne taille seule
ne suffit plus à annuler le choix demi-hauteur. Les apps Enhanced AX sont traitées
temporairement comme dans notre moteur Rooms existant, avec restauration du drapeau.

## 2. Reef — deuxième intégration recommandée

[Documentation consultée](https://getreef.app/docs) : une touche par application,
répétée pour parcourir ses fenêtres ; validation au relâchement du modificateur.
Le parcours est limité au Space courant. Ce n'est pas un moteur de mosaïque.

Sources concrètes :

- `Reef/Models/CyclePanelState.swift` : choix de fenêtre, parcours circulaire,
  action alternative quand l'app n'a pas de fenêtre.
- `Reef/UI/CyclePanel/CyclePanelController.swift` : état du panneau, position
  stable, validation au relâchement ; `CyclePanelView.swift` pour la liste.
- `Reef/Models/Profile.swift`, `UI/Profiles/ProfileManager.swift` : dix slots
  d'apps, profils nommés et sauvegarde JSON différée.
- `Models/Application.swift`, `Models/Window.swift` : inventaire/focus AX.

Raccord : nos raccourcis de lancement pourraient lancer l'app au premier appui,
puis ouvrir un sélecteur de ses fenêtres lors des appuis suivants. Adapter aux
modificateurs gauche/droite, à macOS 13 et au filtrage Space existants ; éviter un
second moniteur global concurrent. Vérifier relâchement, Esc, fermeture en cours
de parcours, app sans fenêtre et absence de saut de bureau involontaire.

## 3. ClickFit — bonnes idées, pas de code publié

Les pages/README annoncent des workspaces, groupes d'onglets inter-apps,
redimensionnement coordonné, layouts personnalisés, palette radiale et gestes.

À retenir d'abord : **redimensionnement lié des deux cellules d'une colonne**,
avec un ratio enregistré dans le Canvas, puis aperçus de zones. L'onglet inter-apps
est plus coûteux : suivi de géométrie/focus, masquage/minimisation réversible et
gestion de fermeture/détachement. Il dépend d'abord d'un registre Rooms fiable.
Les tarifs Free/Pro ne constituent pas une licence autorisant le portage.

## 4. Switch — référence de parcours clavier

README/site : switch par fenêtre plutôt que par app, ordre récent (MRU), recherche,
mode persistant, choix 1–9, miniatures et fenêtres d'autres Spaces. Point important :
le README décrit le **déplacement de la fenêtre choisie vers le Space courant**, pas
seulement la navigation vers son bureau. Ce comportement doit rester une option
distincte chez PK et ne pas casser les strips suspendus.

Prévoir une implémentation indépendante avec notre inventaire, panneau et focus,
ou obtenir une licence adaptée avant un portage. Ne pas importer `WindowFocuser`,
`PrivateSPI` ou le cache AX sous la licence MIT du projet PK.

## 5. Références sans code

- **Moom** : gabarits applicables aux N fenêtres récentes, zones issues d'un layout,
  chaînes/cycles d'actions. Bon prolongement des Rooms une fois la sauvegarde libre faite.
- **Snapback** : rappeler une disposition malgré les changements d'écran, puis
  associer projets/URL/scripts. Réutiliser nos lanceurs existants pour ces derniers.
- **CCCCorners** : déclencheurs coins/zones par écran, modificateurs, délai et
  confirmation par clic. À brancher sur le catalogue de commandes après les moteurs,
  avec désambiguïsation par rapport au scroll et aux fenêtres parquées du Canvas.

## Ordre proposé

1. Valider la correction de demi-hauteur dans la Dev 69.
2. Rooms : édition et **Ma disposition** (P1), migration et tests de rappel.
3. Rooms : isolement réversible + **Tout montrer**, journal commun avec Canvas.
4. Reef : sélecteur de fenêtres par app, puis profils de raccourcis si utiles.
5. Redimensionnement lié et gabarits Moom/ClickFit ; résilience multi-écrans Snapback.
6. Déclencheurs CCCCorners et sélecteur global de type Switch.

Cet audit ne prétend pas que ces six étapes sont livrées. Seul le correctif Canvas
est implémenté dans cette itération ; les références sont archivées pour la suite.
