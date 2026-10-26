# PKwindowsManagement

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

<img src="icon.png" alt="Icône PKwindowsManagement" width="220">

PKwindowsManagement est une app macOS en barre de menu pour gérer les fenêtres au clavier et lancer rapidement les applications installées.

Version **2026.10.93**

## Vitrine interactive

[Découvrir la vitrine](store/website/index.html) : présentation FR/EN, fonctionnalités détaillées, playground de fenêtres et aperçus des thèmes Big Year.

![Launchpad compact — capture native avec données fictives](store/website/screenshots/launchpad-fr.webp)
![Big Year — calendrier annuel natif, thème Poster bleu](store/website/screenshots/year-poster.webp)
![Carte clavier Dev — touches adaptatives et raccourcis Canvas par fenêtre](store/sources/screenshots/keyboard-1440-fr.png)

- [Démo vidéo](store/website/videos/window-flow.mp4) · [GIF animé](store/website/gifs/window-flow-wide.gif)
- [Télécharger le dernier Stable publié — v2026.10.49](https://github.com/mondary/PKwindowsManagement/releases/latest/download/PKwindowsManagement_2026.10.49.dmg) : montez le DMG, glissez l'app dans Applications et autorisez l'Accessibilité. Build Apple Silicon pour macOS 13+.
- Homebrew : `brew install --cask mondary/tap/pk-windows-management` (mise à jour : `brew upgrade --cask pk-windows-management`).
- curl : `curl -L -o PKwindowsManagement.dmg https://github.com/mondary/PKwindowsManagement/releases/latest/download/PKwindowsManagement_2026.10.49.dmg`
- [Sources et limites des captures](store/media-kit/README.md)

## ✅ Fonctionnalités
- Snap des fenêtres actives sur les moitiés, tiers, quarts et coins de l'écran.
- `Tout maximiser` : passe toutes les fenêtres visibles de tous les écrans en presque maximisé, raccourci par défaut `Ctrl + Option + G`.
- `Tout maximiser (app active)` : idem, limité aux fenêtres de l'application au premier plan, raccourci par défaut `Ctrl + Shift + D`. Les fenêtres en plein écran (Chrome, etc.) sortent d'abord du plein écran et de leur Space avant d'être presque maximisées.
- `Paver le bureau actuel` : `Ctrl + Option + T` cible uniquement le Space actif. `Paver tous les bureaux` est une commande séparée, avec un raccourci configurable vide par défaut. Chaque bureau/écran reçoit son propre bento bord à bord : 4 fenêtres en 2×2, des cases de tailles variées dans les compositions denses, jusqu’à 12 selon la place disponible. Les fenêtres partagées entre plusieurs bureaux sont exclues ; le surplus reste derrière.
- Déplacement de la fenêtre vers l'écran suivant ou précédent.
- Gestion expérimentale des bureaux macOS (Spaces) : création/fermeture, déplacement de la fenêtre active vers le bureau voisin et fond d’écran aléatoire optionnel depuis un dossier choisi.
- Ces commandes utilisent des API privées de macOS ; Mission Control peut apparaître brièvement et une mise à jour système peut nécessiter une adaptation.
- Raccourcis clavier configurables depuis une interface SwiftUI.
- Détection des conflits de raccourcis : une combinaison déjà utilisée ailleurs est signalée avec la commande qui s'exécute réellement, et les refus d'enregistrement macOS remontent au lieu de rester silencieux.
- Contrôle de la fenêtre focalisée via les API d'accessibilité macOS.
- Launchpad plein écran avec recherche, applications récentes et raccourcis personnalisés.
- Navigation du Launchpad au clavier : saisie pour filtrer, flèches pour sélectionner et `Entrée` pour lancer.
- Raccourcis globaux par application, actifs partout sur macOS même quand le Launchpad est fermé.
- Distinction gauche/droite pour les modificateurs : Command, Option et Shift (ex : Right Command + A ≠ Left Command + A).
- Support du modificateur `Fn + Shift` pour les raccourcis de lancement.
- Enregistrement des séquences clavier pour les raccourcis.
- Boutons dédiés pour les touches spéciales (Space, Return, Tab, Delete, flèches).
- Gestionnaire de snippets avec scripts exécutables et raccourcis globaux.
- Snippet `Archive` présent par défaut : range le Bureau dans une archive locale instantanée, utilise des dossiers mensuels en français (`2026_06_juin`), puis recopie vers Google Drive en arrière-plan, avec icône dédiée et raccourci `Right Cmd + S`.
- Snippet `DL2desk` présent par défaut : déplace le contenu de `Downloads` vers le Bureau, avec renommage automatique en cas de conflit et raccourci `Right Cmd + L`.
- Icône dossier pour les snippets Finder qui ouvrent `Applications`, `Home` ou `Documents`.
- Gestionnaire d'URLs avec choix du navigateur et raccourcis globaux.
- Tri configurable des applications du Launchpad par dernier lancement, nom, couleur dominante ou ordre personnalisé par glisser-déposer.
- Regroupement par catégories avec tri indépendant : catégories les plus fournies, ordre alphabétique ou ordre personnalisé par glisser-déposer ; les apps gardent leur propre critère de tri dans chaque catégorie.
- Le tri général choisi dans `Appearance` (dernier lancement, nom, couleur ou personnalisé) s'applique aussi quand le regroupement par catégorie est désactivé ; l'ordre des catégories ne concerne que l'affichage groupé.
- Paramétrage fin de la grille du Launchpad : colonnes, lignes, taille des icônes, espacement des colonnes et des lignes.
- Profils de grille par écran pour adapter le Launchpad à chaque moniteur connecté.
- Choix du mode de navigation du Launchpad : scroll vertical continu ou pages horizontales.
- Alignement en haut des pages en mode navigation horizontale.
- Vue `Big Year` plein écran sans scroll : thèmes Pastel, Catppuccin Latte/Mocha, Dracula ou Poster bleu (12 mois × 31 jours), week-ends, jours fériés français, vacances scolaires A/B/C, anniversaires avec `🎂` et événements personnalisés ; fermeture par bouton, `Échap` ou `Cmd + W`.
- Indicateur de statut d'accessibilité avec bouton pour autoriser l'accès.
- Export automatique des backups vers un dossier au choix (ex : Google Drive) à chaque modification des réglages.
- Menu contextuel sur chaque application pour attribuer un raccourci ou la déplacer vers la Corbeille.
- Commande `Empty Trash` dans le Launchpad pour vider la Corbeille via Finder.
- Ouverture du Launchpad avec `Option + Espace`, le coin supérieur gauche ou un clic sur l'icône de barre de menu.
- L'icône officielle de l'app s'affiche dans la barre de menu (en couleur) ; menu contextuel pour ouvrir les préférences ou quitter.
- Mises à jour Sparkle dans `À propos` : compare la version installée aux dernières versions Stable et Dev ; chaque canal indique s'il est à jour, propose une mise à jour ou correspond à l'autre canal.
- Chargement plus léger au démarrage : les raccourcis globaux n'ont plus besoin de charger toutes les icônes d'applications, et l'analyse couleur ne se fait que pour le tri `Icon Color`.

## 🧠 Utilisation
- Ouvre l'application.
- Autorise l'accès à l'accessibilité quand macOS le demande.
- Utilise les raccourcis par défaut pour déplacer la fenêtre active.
- Utilise `Option + Espace` pour afficher ou masquer le Launchpad.
- Dans le Launchpad, commence à saisir puis appuie sur `Entrée` pour lancer le premier résultat.
- Utilise les flèches pour changer de sélection.
- Utilise la molette ou le trackpad pour naviguer dans le Launchpad.
- Appuie sur `Échap` une fois pour vider une recherche, puis une seconde fois pour fermer le Launchpad.
- Clique sur `•••` en haut à droite pour ouvrir les réglages.
- Utilise `Right Cmd + L` pour déplacer les éléments de `Downloads` vers le Bureau avec `DL2desk`.
- Lance `Empty Trash` depuis le Launchpad pour vider la Corbeille. Au premier usage, macOS peut demander l'autorisation d'automatiser Finder.
- Utilise `Cmd + ,` pour ouvrir les réglages depuis l'application.

### Raccourcis par défaut
- `Ctrl + Option + H` : moitié gauche
- `Ctrl + Option + L` : moitié droite
- `Ctrl + Option + K` : moitié haute
- `Ctrl + Option + J` : moitié basse
- `Ctrl + Option + M` : maximiser
- `Ctrl + Option + C` : centrer
- `Ctrl + Option + U` : coin haut gauche
- `Ctrl + Option + I` : coin haut droit
- `Ctrl + Option + N` : coin bas gauche
- `Ctrl + Option + O` : coin bas droit
- `Ctrl + Option + 1` : tiers gauche
- `Ctrl + Option + 2` : tiers central
- `Ctrl + Option + 3` : tiers droit
- `Ctrl + Option + [` : écran précédent
- `Ctrl + Option + Space` : écran suivant
- `Ctrl + Option + =` : agrandir depuis le centre
- `Ctrl + Option + -` : réduire depuis le centre
- `Ctrl + Option + B` : créer un bureau
- `Ctrl + Option + W` : fermer le bureau actuel
- `Ctrl + Shift + →` / `←` : déplacer la fenêtre active vers le bureau virtuel (Space) suivant / précédent

## ⚙️ Réglages
- **Aperçus de fenêtres** (build Dev locale) : `Ctrl+Option+Tab`, menu **Ouvrir les aperçus de fenêtres** ou bouton dans **Fenêtres**. Recherchez une app ou un titre ; `Tab`/`Maj+Tab` parcourent, `↑`/`↓` changent de ligne, `Entrée` ou un clic active la fenêtre, `⌘1–9` donne un accès direct, `Échap` annule, `⌘R` actualise. **`⌘W` ou le bouton × ferme uniquement la fenêtre ciblée**, en gardant le sélecteur et la recherche ouverts pour poursuivre le tri. Les demandes d’enregistrement restent à traiter dans l’app concernée. **`⌘Q` quitte l’app de la fenêtre sélectionnée** avec un arrêt gracieux. Le raccourci global reste modifiable. L’option **Utiliser ⌘Tab pour ouvrir les aperçus de fenêtres** (Fenêtres) remplace le sélecteur d’apps de macOS : maintenez `⌘`, `⇥`/`⇧⇥` parcourent et relâcher `⌘` active ; `Échap` annule. Tapez directement pendant que `⌘` est maintenu pour filtrer. L’option **Garder le sélecteur ouvert au relâchement de ⌘** permet de relâcher puis de rechercher, `Entrée` active la fenêtre. Autorisez **Enregistrement de l’écran** pour les miniatures (bouton **Autoriser les aperçus…** dans Réglages → Fenêtres) ; sans cette permission, icônes et titres restent affichés. Captures à l’ouverture/actualisation, conservées uniquement en mémoire ; une fenêtre minimisée ou indisponible peut ne pas fournir d’aperçu. Les fenêtres d’autres Spaces exposées par Accessibility sont proposées ; leur activation suit macOS sans les rapatrier. **Seules les fenêtres des apps normales sont listées** : les apps de barre de menus, les widgets du Bureau ou du Centre de notifications et les panneaux système sont exclus. Les tuiles ont toutes la même taille ; l'aperçu est cadré sans déformation, avec une légende discrète posée directement sur le panneau (sans fond blanc ni séparateur) et le badge `⌘1–9` en surimpression. [Aperçu de l’interface avec données fictives](store/sources/screenshots/window-previews-fr.png).
- Les mises à jour intégrées attendent la restauration du Canvas et la fermeture effective de l’app avant son remplacement et son relancement. Si une ancienne Dev reste bloquée à cette étape, un redémarrage de l’app peut être nécessaire ; voir le [CHANGELOG](CHANGELOG.md).
- Le menu **Ouvrir les réglages** réutilise la fenêtre même après fermeture. **Rechercher les mises à jour** ouvre cette fenêtre et affiche la progression et la proposition d’installation depuis tous les onglets.
- Le canal **Dev** est publié par GitHub Actions après chaque push de code sur `main` (pas de branche `dev` séparée). Un build installé localement n'est pas encore une mise à jour publiée. Une ancienne version du même canal n'est plus proposée ; revenir en arrière exige de changer réellement de canal.
- **VS Code / Electron** : le Canvas et `Ctrl+Option+T` réconcilient les inventaires Accessibility partiels (réservé aux commandes explicites pour ne pas ralentir le strip). Aucun plafond de 10 ou 12 fenêtres ; les contraintes d'Accessibilité, de minimisation et de bureau restent applicables. `Ctrl+Option+T` conserve son périmètre : l'app au premier plan. Les choix demi-hauteur survivent à la désactivation du strip.
- **Canvas horizontal** (canal Dev) : chaque fenêtre commence en pleine hauteur. `Ctrl+Shift+S` passe la fenêtre active en demi-hauteur ; la suivante choisie rejoint la première en dessous, même depuis une colonne distante. `Ctrl+Shift+F` détache uniquement la fenêtre ciblée en pleine hauteur. Les paires et le défilement restent mémorisés par écran et bureau pendant la session : changer de bureau suspend le strip, revenir le reprend. Une fenêtre refusant la demi-hauteur garde sa propre colonne. `Ctrl+Shift+Espace` active/désactive ; `Ctrl+Shift+H/L` change de colonne et `Ctrl+Shift+K/J` de ligne. Défilement horizontal au trackpad, ou `⌥` + défilement vertical. La sortie restaure les positions et tailles d'origine ; un snap quitte le Canvas du bureau courant avant de placer la fenêtre. **Diagnostiquer les fenêtres du Canvas**, dans Fenêtres, affiche les exclusions (Accessibilité, dialogue, plusieurs bureaux…). Voir le [CHANGELOG](CHANGELOG.md).
- **Rooms** (canal Dev, `Ctrl+Option+R` ou **Réglages → Rooms**) : ensembles de fenêtres nommés avec disposition (Auto/Focus/Colonnes/Grille/Pile). À la création, choisis les fenêtres dans l'ordre (1 = place principale) et **l'écran cible** ; à l'activation, la mosaïque s'applique sur cet écran (repli sur l'écran du pointeur s'il est débranché), les apps manquantes sont lancées et leurs fenêtres attendues. Boutons **Ouvrir / Changer la disposition / Minimiser** dans le panneau. `⇥` change la disposition, `⌘1-9` ouvre la n-ième room, `⌘↓` minimise ses fenêtres (la réactivation les ramène), `⌘⌫` supprime. Ouvrir le panneau laisse le Canvas actif ; une action de room le libère sur les bureaux visibles. Voir le [CHANGELOG](CHANGELOG.md).

- **Gestion des rooms** : page dédiée **Rooms** dans la barre latérale, également accessible par **Gérer Rooms…** dans le menu de l’app. Crée, ouvre, minimise ou modifie tes projets. L’éditeur permet de renommer, changer la disposition/l’écran, ajouter/retirer des fenêtres et les réordonner. La suppression d’une room peut être annulée ; elle ne ferme aucune fenêtre. Les rooms existantes restent dans le même fichier `rooms.json`.
- [Aperçu natif de la page Rooms](store/sources/screenshots/rooms-fr.png).
- **Réglages inspirés de Moom** : choisis une disposition avec son aperçu dans l’éditeur ; duplique une room pour créer une variante sans modifier l’originale. [Aperçu de l’éditeur](store/sources/screenshots/room-editor-fr.png) · [Pistes suivantes](docs/moom-settings-inspiration.md).
- Dans `Raccourcis fenêtre` → `Bureaux`, affecte un raccourci à **Déplacer le bureau à gauche/droite** pour réordonner le bureau avec son contenu. Mission Control apparaît brièvement ; désactive le réagencement automatique des Spaces dans macOS pour conserver ton ordre. Glisser réel en cours de validation sur Dev.
- Les raccourcis sont modifiables dans l'écran de préférences.
- Dans `Raccourcis fenêtre` → `Bureaux`, configure la création, la fermeture et le déplacement entre Spaces. Tu peux choisir un dossier de fonds d’écran, activer la sélection aléatoire à la création et décider si l’app bascule vers le bureau de destination après un déplacement.
- Sur Dev, lorsque le suivi est activé, les déplacements successifs conservent la même fenêtre comme cible, même si macOS perturbe le focus. Un clic, `Cmd+Tab` ou une autre commande de fenêtre/application démarre une nouvelle sélection. Les raccourcis rapides sont exécutés dans l’ordre ; Mission Control impose toujours son temps de transition. Validation réelle du correctif en cours.
- La gestion des Spaces est expérimentale : elle s’appuie sur des API privées SkyLight et l’arbre d’accessibilité de Mission Control/WindowManager. La création et la fermeture, ainsi que le suivi après déplacement, peuvent brièvement afficher Mission Control ; une mise à jour majeure de macOS peut casser ces appels.
- Modificateurs disponibles : Control+Option, Command, Left/Right Command, Option, Left/Right Option, Shift, Left/Right Shift, Fn+Shift.
- Un clic droit sur une application permet d'attribuer ou modifier son raccourci global.
- Les raccourcis attribués apparaissent sur les icônes sous forme de touches.
- Enregistrement des raccourcis via un bouton `Record`.
- Les réglages s’ouvrent sur **Fenêtres**. La **carte clavier** s’étend sur la largeur disponible, avec touches et libellés agrandis et commandes multiples séparées. Elle suit tes raccourcis actuels (`Y` quart haut-gauche, `U/I/O/J/K/L` sixièmes, `1/2/3` tiers, `P`/`H`/`M` quarts). Les marges affichent **Haut, Bas, Gauche, Droite** ; le **Canvas horizontal (Open Canvas)** regroupe ses commandes de navigation et de hauteur par fenêtre.
- **Scripts** et **Liens web** sont deux rubriques distinctes, suivies de **Big Year**. **Système**, sous IA locale, regroupe langue, accessibilité et sauvegardes.
- **Launchpad** conserve le raccourci global et le coin actif, présentés côte à côte. **Apparence** s’affiche en colonnes : style, organisation par catégorie (aperçus graphiques), grille, dispositions par écran, ordre et navigation. En **Compact**, seul le thème compact apparaît ; les blocs de grille, catégories, ordre et navigation sont réservés au style **Plein écran**.
- Ordre des applications du Launchpad configurable dans `Appearance` : `Last Used`, `Name`, `Icon Color` ou `Custom Order` (glisser-déposer dans le Launchpad).
- Dans `Apparence` → `Organisation`, active le regroupement par catégorie et choisis leur ordre : catégories les plus fournies, alphabétique ou personnalisé (glisser-déposer les pastilles dans le Launchpad).
- Paramétrage de la grille du Launchpad : nombre de colonnes/lignes, taille des icônes, espacement des colonnes et des lignes.
- Possibilité de définir une grille spécifique par écran dans les réglages d'apparence.
- Choix du mode de navigation du Launchpad : scroll vertical ou pages horizontales.
- Les changements sont sauvegardés dans `UserDefaults`.
- Dans `À propos`, choisis le canal de mise à jour `Stable` ou `Dev` et compare la version installée aux dernières versions publiées sur chaque canal. Le canal Dev installe les builds automatiquement ; Stable conserve la confirmation avant installation.
- La barre latérale garde la version installée et la version disponible sur une même ligne, sans déplacer les drapeaux ; clique sur la version proposée pour lancer l'installation. Les vérifications manuelles s'appuient sur l'appcast frais et l'archive signée du canal.
- Import/export manuel des réglages au format JSON.
- Auto-backup : choisis un dossier (ex : Google Drive) et exporte un backup JSON horodaté à chaque modification des réglages.
- Dans le calendrier ou sa section dédiée `Big Year` des réglages, utilise l’aperçu vivant, choisis la zone scolaire, le thème et l’apparence : anniversaires ou noms des mois en gras au choix (le `!` reste prioritaire), et couleurs personnalisées pour chaque élément (fond, jours fériés, anniversaires, événements, zones, texte…). Puis saisis un anniversaire par ligne au format `JJ.MM,Prénom` ou `JJMM,Prénom` (par exemple `11.02,Clément` ou `0112,Marie`). Préfixe le prénom par `!` pour un événement important en gras. Clique aussi directement sur une journée pour créer un événement d'un jour ou une plage, ou utilise le format texte `JJ.MM-JJ.MM,Titre`. Active `Calendriers macOS / Google` pour importer les événements journée entière des comptes configurés dans Calendrier macOS.

## 🧾 Commandes
- Clic gauche sur l'icône de barre de menu : ouvre ou ferme le Launchpad.
- Clic droit sur l'icône de barre de menu : affiche les actions Launchpad/Big Year, les raccourcis configurés, puis `Check for Updates`, `Open Preferences`, Ko-fi et `Quit`.
- `Open Big Year` : ouvre la vue annuelle plein écran. `Échap` ou `Cmd + W` la ferment, `Cmd + Q` quitte l'app.
- `Cmd + ,` : ouvre les réglages.

## 📦 Build & Package
- Prérequis : macOS 13 ou plus.
- Swift tools : 5.10.
- Build local :
```bash
swift build
```
- Création du bundle debug et lancement :
```bash
src/script/build_and_run.sh
```
- Création du bundle sans lancement :
```bash
src/script/package_app.sh debug
src/script/package_app.sh release
```
- Création d'une app testable sur le Bureau :
```bash
src/script/package_app.sh debug
rm -rf ~/Desktop/PKwindowsManagement.app
ditto build/PKwindowsManagement.app ~/Desktop/PKwindowsManagement.app
```
- Création d'une release et copie dans `/Applications` :
```bash
src/script/release.sh
```

## 🧪 Installation
- Lance `src/script/release.sh` pour compiler et installer `/Applications/PKwindowsManagement.app`.
- Garde l'app installée au même chemin (`/Applications/PKwindowsManagement.app`) et construis-la toujours avec `src/script/package_app.sh` ou `src/script/release.sh` pour conserver le même identifiant, la même signature et éviter que macOS redemande inutilement les autorisations.
- Au premier usage, valide l'accès à l'accessibilité dans `Réglages Système > Confidentialité et sécurité > Accessibilité`. Cette permission est nécessaire pour gérer les fenêtres et écouter les raccourcis globaux.
- Pour `Empty Trash`, valide aussi l'autorisation d'automatisation Finder quand macOS la demande. Cette commande passe par Finder car macOS bloque l'accès direct au dossier `~/.Trash`.
- Si l'app n'agit pas sur les fenêtres, vérifie aussi les permissions de l'app cible si nécessaire.

## 🙏 Crédits

PKwindowsManagement s'appuie sur des projets open source et s'en inspire — les crédits sont dans l'app, dans la section dédiée **Crédits & inspirations** :

- [Rooms](https://github.com/saragordic/rooms) (Sara Gordić, MIT) — concept des rooms et moteur de disposition porté en RoomTiler.
- [Sparkle 2](https://github.com/sparkle-project/Sparkle) (MIT) — mises à jour automatiques Stable/Dev.
- [Laya](https://huggingface.co/convaiinnovations/laya) (Convai Innovations, Apache-2.0) — modèle de décision local derrière l'IA intégrée.
- [Hammerspoon](https://github.com/Hammerspoon/hammerspoon) (MIT) — techniques d’accessibilité Mission Control et de gestion des Spaces.
- [yabai](https://github.com/asmvik/yabai) (MIT) — techniques de compatibilité SkyLight pour déplacer les fenêtres entre Spaces.

Références étudiées pour la suite : [inventaire vendors](vendors/README.md) et
[plan d'intégration Rooms, Reef, ClickFit, Switch, Moom, Snapback et CCCCorners](docs/window-management-inspirations.md).
Rooms est prioritaire ; cet audit distingue les sources réutilisables des références fonctionnelles.

## 🧾 Changelog
- Voir [CHANGELOG.md](CHANGELOG.md) pour l'historique complet.

## 🔗 Liens
- EN README : [README_en.md](README_en.md)
- Changelog : [CHANGELOG.md](CHANGELOG.md)

## ❤️ Soutenir
Soutenir ce projet sur [Ko-fi](https://ko-fi.com/pouark).
