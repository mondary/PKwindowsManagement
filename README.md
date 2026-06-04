# PKwindowsManagement

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

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
- Paramétrage fin de la grille du Launchpad : taille des icônes, espacement des colonnes et des lignes.
- Alignement en haut des pages en mode navigation horizontale.
- Indicateur de statut d'accessibilité avec bouton pour autoriser l'accès.
- Export automatique des backups vers un dossier au choix (ex : Google Drive) à chaque modification des réglages.
- Menu contextuel sur chaque application pour attribuer un raccourci ou la déplacer vers la Corbeille.
- Ouverture du Launchpad avec `Option + Espace`, le coin supérieur gauche ou un clic sur l'icône de barre de menu.
- Icône d'application dédiée et menu contextuel pour ouvrir les préférences ou quitter.

## 🧠 Utilisation
- Ouvre l'application.
- Autorise l'accès à l'accessibilité quand macOS le demande.
- Utilise les raccourcis par défaut pour déplacer la fenêtre active.
- Utilise `Option + Espace` pour afficher ou masquer le Launchpad.
- Dans le Launchpad, commence à saisir puis appuie sur `Entrée` pour lancer le premier résultat.
- Utilise les flèches pour changer de sélection.
- Appuie sur `Échap` une fois pour vider une recherche, puis une seconde fois pour fermer le Launchpad.
- Clique sur `•••` en haut à droite pour ouvrir les réglages.

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
- Paramétrage de la grille du Launchpad : nombre de colonnes/lignes, taille des icônes, espacement des colonnes et des lignes.
- Les changements sont sauvegardés dans `UserDefaults`.
- Import/export des réglages au format JSON.
- Auto-backup : choisis un dossier (ex : Google Drive) et exporte un backup JSON horodaté à chaque modification des réglages.

## 🧾 Commandes
- Clic gauche sur l'icône de barre de menu : ouvre ou ferme le Launchpad.
- Clic droit sur l'icône de barre de menu : affiche `Open Launchpad`, `Open Preferences` et `Quit`.

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
- Création d'une release et copie dans `/Applications` :
```bash
script/release.sh
```

## 🧪 Installation
- Lance `script/release.sh` pour compiler et installer `/Applications/PKwindowsManagement.app`.
- Au premier usage, valide l'accès à l'accessibilité dans `Réglages Système > Confidentialité et sécurité > Accessibilité`. Cette permission est nécessaire pour gérer les fenêtres et écouter les raccourcis globaux.
- Si l'app n'agit pas sur les fenêtres, vérifie aussi les permissions de l'app cible si nécessaire.

## 🧾 Changelog
- `0.12` - 2026-06-04
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
