# PKwindowsManagement

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

<img src="icon.png" alt="Icône PKwindowsManagement" width="220">

PKwindowsManagement est une app macOS en barre de menu pour gérer les fenêtres au clavier et lancer rapidement les applications installées.

## ✅ Fonctionnalités
- Snap des fenêtres actives sur les moitiés, tiers, quarts et coins de l'écran.
- Déplacement de la fenêtre vers l'écran suivant ou précédent.
- Raccourcis clavier configurables depuis une interface SwiftUI.
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
- Tri configurable des applications du Launchpad par nom, dernière utilisation ou couleur dominante de l'icône.
- Paramétrage fin de la grille du Launchpad : colonnes, lignes, taille des icônes, espacement des colonnes et des lignes.
- Profils de grille par écran pour adapter le Launchpad à chaque moniteur connecté.
- Choix du mode de navigation du Launchpad : scroll vertical continu ou pages horizontales.
- Alignement en haut des pages en mode navigation horizontale.
- Vue `Big Year` plein écran depuis le menu, avec fermeture par bouton, `Échap` ou `Cmd + W`.
- Indicateur de statut d'accessibilité avec bouton pour autoriser l'accès.
- Export automatique des backups vers un dossier au choix (ex : Google Drive) à chaque modification des réglages.
- Menu contextuel sur chaque application pour attribuer un raccourci ou la déplacer vers la Corbeille.
- Commande `Empty Trash` dans le Launchpad pour vider la Corbeille via Finder.
- Ouverture du Launchpad avec `Option + Espace`, le coin supérieur gauche ou un clic sur l'icône de barre de menu.
- L'icône officielle de l'app s'affiche dans la barre de menu (en couleur) ; menu contextuel pour ouvrir les préférences ou quitter.
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
- `Ctrl + Option + ]` : écran suivant

## ⚙️ Réglages
- Les raccourcis sont modifiables dans l'écran de préférences.
- Modificateurs disponibles : Control+Option, Command, Left/Right Command, Option, Left/Right Option, Shift, Left/Right Shift, Fn+Shift.
- Un clic droit sur une application permet d'attribuer ou modifier son raccourci global.
- Les raccourcis attribués apparaissent sur les icônes sous forme de touches.
- Enregistrement des raccourcis via un bouton `Record`.
- Gestion des snippets `Scripts` et `URLs` dans des onglets séparés des réglages.
- Ordre des applications du Launchpad configurable dans `Appearance` : `Last Used`, `Name` ou `Icon Color`.
- Paramétrage de la grille du Launchpad : nombre de colonnes/lignes, taille des icônes, espacement des colonnes et des lignes.
- Possibilité de définir une grille spécifique par écran dans les réglages d'apparence.
- Choix du mode de navigation du Launchpad : scroll vertical ou pages horizontales.
- Les changements sont sauvegardés dans `UserDefaults`.
- Import/export manuel des réglages au format JSON.
- Auto-backup : choisis un dossier (ex : Google Drive) et exporte un backup JSON horodaté à chaque modification des réglages.

## 🧾 Commandes
- Clic gauche sur l'icône de barre de menu : ouvre ou ferme le Launchpad.
- Clic droit sur l'icône de barre de menu : affiche `Open Launchpad`, `Open Big Year`, `Open Preferences` et `Quit`.
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
script/build_and_run.sh
```
- Création du bundle sans lancement :
```bash
script/package_app.sh debug
script/package_app.sh release
```
- Création d'une app testable sur le Bureau :
```bash
script/package_app.sh debug
rm -rf ~/Desktop/PKwindowsManagement.app
ditto dist/PKwindowsManagement.app ~/Desktop/PKwindowsManagement.app
```
- Création d'une release et copie dans `/Applications` :
```bash
script/release.sh
```

## 🧪 Installation
- Lance `script/release.sh` pour compiler et installer `/Applications/PKwindowsManagement.app`.
- Garde l'app installée au même chemin (`/Applications/PKwindowsManagement.app`) et construis-la toujours avec `script/package_app.sh` ou `script/release.sh` pour conserver le même identifiant, la même signature et éviter que macOS redemande inutilement les autorisations.
- Au premier usage, valide l'accès à l'accessibilité dans `Réglages Système > Confidentialité et sécurité > Accessibilité`. Cette permission est nécessaire pour gérer les fenêtres et écouter les raccourcis globaux.
- Pour `Empty Trash`, valide aussi l'autorisation d'automatisation Finder quand macOS la demande. Cette commande passe par Finder car macOS bloque l'accès direct au dossier `~/.Trash`.
- Si l'app n'agit pas sur les fenêtres, vérifie aussi les permissions de l'app cible si nécessaire.

## 🧾 Changelog
- `0.19` - 2026-07-06
  - Correction enregistrement : détection de la barre d'espace par keyCode physique (kVK_Space) au lieu de `charactersIgnoringModifiers`.
  - Remplacement du moniteur NSEvent local par un CGEvent tap (évite l'interception système des touches comme CMD+Espace).
  - Correction frappe « space » dans le champ texte : buffer local au lieu d'un binding qui tronquait le mot lettre à lettre.
  - Correction du matching runtime (LaunchShortcutMonitor) : comparaison par keyCode pour Space, Return, Tab, Delete, flèches.
  - Correction bug localisation français : `normalizedKey("Espace")` échouait → stockait « e » au lieu de « space ».
  - Menu barre : affichage du vrai raccourci Launchpad au lieu de « CMD+Espace » en dur.
  - Nouvelles touches spéciales dans l'éditeur de raccourci : boutons Space ␣, Return ↵, Tab ⇥, Delete ⌫, flèches ←→↑↓.
  - Affichage unifié des touches spéciales dans les badges et labels.
  - `0.18` - 2026-06-16
  - L'icône officielle de l'app s'affiche dans la barre de menu (en couleur) et dans l'en-tête des réglages.
  - Snippet `Archive` présent par défaut avec icône dédiée et raccourci `Right Cmd + S`.
  - Snippet `DL2desk` ajouté par défaut pour déplacer `Downloads` vers le Bureau avec le raccourci `Right Cmd + L`.
  - Icônes dossier pour les snippets Finder personnalisés ou par défaut qui ouvrent des dossiers.
  - Commande `Empty Trash` fonctionnelle via l'automatisation Finder, avec feedback lisible si macOS bloque l'autorisation.
  - Packaging documenté pour conserver un bundle signé stable et éviter les redemandes d'autorisations macOS à chaque mise à jour.
  - Archive « Conserver les deux » en cas d'homonymes (`fichier 2.ext`).
  - Archive locale d'abord (instantanée) puis recopie Google Drive en arrière-plan limitée — plus de freeze sur les gros dossiers.
  - Dossiers mensuels Archive forcés en français (`2026_06_juin`) même si macOS lance le script avec une locale anglaise.
  - Raccourci `DesktopArchive` pointant vers l'archive Google Drive quand elle est détectée, sinon vers l'archive locale.
  - Fusion des doublons `Archive` en une seule entrée (raccourci existant conservé).
- `0.17` - 2026-06-16
  - Ajout de `Big Year` depuis le menu de la barre de menu.
  - Sécurisation de la fermeture de l'overlay annuel (`Échap`, `Cmd + W`, bouton fermer, niveau de fenêtre moins intrusif).
  - Démarrage et refresh des raccourcis plus légers : le moniteur global ne charge plus toutes les icônes d'applications.
  - Le tri par couleur ne calcule la couleur dominante des icônes que quand le mode `Icon Color` est actif.
  - Nettoyage plus complet des timers, event taps et handlers globaux à la fermeture.
- `0.16` - 2026-06-05
  - Tri configurable des applications du Launchpad par nom, dernière utilisation ou couleur dominante de l'icône.
- `0.15` - 2026-06-05
  - Onglet `URLs` dédié dans les réglages, séparé des scripts.
  - Snippets `URL` avec choix du navigateur et raccourcis globaux.
  - Icône de favicon récupérée automatiquement pour les snippets `URL` quand le site en fournit une.
  - Icônes Launchpad des scripts et URLs rendues plus lisibles.
- `0.14` - 2026-06-05
  - Gestionnaire de snippets avec scripts exécutables, raccourcis globaux et activation/désactivation.
  - Barre de recherche Launchpad capable d'effectuer des calculs simples avec unités.
  - Éditeur snippets refondu et Launchpad ajusté pour les commandes système.
- `0.13` - 2026-06-05
  - Profils de grille Launchpad par écran connecté.
  - Bouton `Record` pour enregistrer les raccourcis au clavier.
  - Grille Launchpad étendue jusqu'à `20 × 20`.
- `0.12` - 2026-06-04
  - Choix du mode de navigation Launchpad : vertical continu ou pages horizontales.
  - Import/export manuel des réglages en JSON.
  - `Cmd + ,` pour ouvrir les réglages.
  - Distinction gauche/droite pour Command, Option et Shift dans les raccourcis.
  - Support du modificateur Fn + Shift.
  - Paramétrage fin de la grille : taille des icônes, espacement colonnes/lignes.
  - Alignement en haut des pages en navigation horizontale.
  - Indicateur de statut d'accessibilité avec bouton d'autorisation.
  - Auto-backup vers un dossier au choix à chaque modification des réglages.
  - Correction du texte de la barre de recherche (blanc sur fond sombre).
- `0.10` - 2026-06-03
  - Initial project scaffold.

## 🔗 Liens
- EN README : [README_en.md](README_en.md)
- Changelog : [CHANGELOG.md](CHANGELOG.md)
