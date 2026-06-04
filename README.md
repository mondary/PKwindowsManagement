# PKwindowsManagement

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

PKwindowsManagement est une app macOS en barre de menu pour gérer les fenêtres au clavier et lancer rapidement les applications installées.

## ✅ Fonctionnalités
- Snap des fenêtres actives sur les moitiés, tiers, quarts et coins de l'écran.
- Déplacement de la fenêtre vers l'écran suivant ou précédent.
- Raccourcis clavier configurables depuis une interface SwiftUI.
- Contrôle de la fenêtre focalisée via les API d'accessibilité macOS.
- Launchpad plein écran avec recherche, applications récentes et raccourcis personnalisés.
- Ouverture du Launchpad avec `Option + Espace`, le coin supérieur gauche ou un clic sur l'icône de barre de menu.
- Icône d'application dédiée et menu contextuel pour ouvrir les préférences ou quitter.

## 🧠 Utilisation
- Ouvre l'application.
- Autorise l'accès à l'accessibilité quand macOS le demande.
- Utilise les raccourcis par défaut pour déplacer la fenêtre active.
- Utilise `Option + Espace` pour afficher ou masquer le Launchpad.

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
- Les applications peuvent recevoir un raccourci de lancement dédié depuis l'écran Launchpad.
- Les changements sont sauvegardés dans `UserDefaults`.
- L'edge du drawer clipboard est aussi conservé via les réglages de l'app.

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
- Au premier usage, valide l'accès à l'accessibilité dans `Réglages Système > Confidentialité et sécurité > Accessibilité`.
- Si l'app n'agit pas sur les fenêtres, vérifie aussi les permissions de l'app cible si nécessaire.

## 🧾 Changelog
- `0.10` - 2026-06-03
  - Initial project scaffold.

## 🔗 Liens
- EN README : [README_en.md](README_en.md)
- Changelog : [CHANGELOG.md](CHANGELOG.md)
