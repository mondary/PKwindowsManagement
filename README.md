# PKwindowsManagement

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

<img src="icon.png" alt="Icône PKwindowsManagement" width="220">

PKwindowsManagement est une app macOS en barre de menu pour gérer les fenêtres au clavier et lancer rapidement les applications installées.

## ✅ Fonctionnalités
- Snap des fenêtres actives sur les moitiés, tiers, quarts et coins de l'écran.
- `Tout maximiser` : passe toutes les fenêtres visibles de tous les écrans en presque maximisé, raccourci par défaut `Ctrl + Option + G`.
- `Tout maximiser (app active)` : idem, limité aux fenêtres de l'application au premier plan, raccourci par défaut `Ctrl + Shift + D`.
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
- Vue `Big Year` plein écran sans scroll : thèmes Pastel, Catppuccin Latte/Mocha, Dracula ou Poster bleu (12 mois × 31 jours), week-ends, jours fériés français, vacances scolaires A/B/C, anniversaires avec `🎂` et événements personnalisés ; fermeture par bouton, `Échap` ou `Cmd + W`.
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
- `Ctrl + Option + =` : agrandir depuis le centre
- `Ctrl + Option + -` : réduire depuis le centre

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
- Dans le calendrier ou sa section dédiée `Big Year` des réglages, utilise l’aperçu vivant, choisis la zone scolaire, le thème et l’apparence : anniversaires ou noms des mois en gras au choix (le `!` reste prioritaire), et couleurs personnalisées pour chaque élément (fond, jours fériés, anniversaires, événements, zones, texte…). Puis saisis un anniversaire par ligne au format `JJ.MM,Prénom` ou `JJMM,Prénom` (par exemple `11.02,Clément` ou `0112,Marie`). Préfixe le prénom par `!` pour un événement important en gras. Clique aussi directement sur une journée pour créer un événement d'un jour ou une plage, ou utilise le format texte `JJ.MM-JJ.MM,Titre`. Active `Calendriers macOS / Google` pour importer les événements journée entière des comptes configurés dans Calendrier macOS.

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
ditto release/PKwindowsManagement.app ~/Desktop/PKwindowsManagement.app
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

## 🧾 Changelog
- Voir [CHANGELOG.md](CHANGELOG.md) pour l'historique complet.

## 🔗 Liens
- EN README : [README_en.md](README_en.md)
- Changelog : [CHANGELOG.md](CHANGELOG.md)
