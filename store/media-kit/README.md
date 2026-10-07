# Store — kit média et validation

## Ouvrir la vitrine

Ouvrir `store/website/index.html` directement fonctionne, y compris le playground et la bascule FR/EN.
Pour la prévisualisation et les captures depuis la racine du dépôt :

```sh
python3 -m http.server 4178 --bind 127.0.0.1
# http://127.0.0.1:4178/store/website/
```

Site statique autonome, sans build, dépendance JavaScript ni ressource distante à l'exécution.
Les seuls liens externes sont les destinations volontairement ouvertes : GitHub et Ko-fi.
Publier **tout `store/website`** tel quel sur l'hébergement : c'est le dossier prêt pour le dépôt FTP.
Les téléchargements vivent dans la GitHub Release du dépôt, plus dans le site.
Les liens README vers le HTML sur GitHub montrent le fichier ; le serveur local rend le site.
L'URL de déploiement n'étant pas définie, aucune canonical fictive n'est ajoutée. À la mise en
ligne, passer `og:image` en URL publique absolue et ajouter la canonical réelle.

## Arborescence du store

- `website/` : la vitrine déployable (HTML, CSS, JS, médias et liens plein écran référencés).
- `sources/` : originaux non déployés — captures retina PNG, poster source, bannière GitHub,
  GIF compact, provenance du fond et archive ZIP locale avec sa somme SHA-256.
- `media-kit/` : ce kit de régénération et de validation.
- `archive/` : l'ancienne vitrine v1 et son projet vidéo, conservés pour référence.

## Sources visuelles

- `sources/screenshots/launchpad-{fr,en}.png` : `CompactLaunchpadRootView`, code SwiftUI de production.
  Catalogue fictif de cinq apps système, chargé via `CaptureFixtures.apps` dans une copie temporaire.
  Le modèle et les composants de lignes sont ceux de l'app ; seul l'approvisionnement du catalogue
  et des commandes/snippets est remplacé. Recherche et commandes ne sont jamais exécutées.
- `sources/screenshots/windows-{fr,en}.png` : `WindowShortcutsPreferencesView`, cadrage natif du haut de la vue
  défilante. Aucun faux panneau de préférences réimplémenté en HTML.
- `sources/screenshots/year-{pastel,poster,catppuccinMocha}.png` : `BigYearRootView`, année 2026, anniversaires
  Alex/Sam/Charlie et événements fictifs. EventKit désactivé ; téléchargement des vacances neutralisé
  dans une copie temporaire. Les captures ne montrent donc pas les données de vacances scolaires.
  L'indicateur « aujourd'hui » dépend de la date système au moment de la capture.
- Les libellés natifs non traduits par l'app sont conservés. Big Year reste en français dans les
  deux langues de la vitrine : c'est explicitement annoncé sous la capture.
- `website/assets/wallpaper.webp` : fond décoratif du catalogue local de la skill premium-promo-media.
  Paysage sélectionné `2a566450c6f9`, original inspecté visuellement. SHA-256 et métadonnées
  dans `sources/assets/provenance.json`. Ce fond n'est pas une capture de macOS.
- `website/assets/icon.png` : dérivé 160 px de l'icône officielle à la racine.

Le harness ne lance ni AppDelegate, ni raccourcis globaux, ni app cible. Préférences dans une
suite jetable, choix de langue dans le domaine volatile du processus de capture, fenêtres hors
écran, politique d'activation interdite. Aucun presse-papiers ou écran utilisateur capturé.
Sources de production inchangées ; aucun accès au dossier archivé `store/archive/`.

## Régénérer

Prérequis : Python 3 + Pillow, Swift et SDK macOS 26.5, ffmpeg, Ego Lite déjà connecté.
Le SDK 27 par défaut provoque des erreurs de macros SwiftUI avec la toolchain locale : le harness
fixe explicitement le SDK 26.5. Des avertissements préexistants de sources Swift peuvent apparaître.

```sh
python3 store/media-kit/prepare.py
ego-browser nodejs < store/media-kit/capture.mjs
python3 store/media-kit/encode.py
ego-browser nodejs < store/media-kit/verify.mjs
ego-browser nodejs < store/media-kit/measure.mjs
git diff --check
```

Avant une nouvelle session, adapter l'id TaskSpace `38` dans les scripts Ego au nouvel espace
créé, ainsi que les chemins `base` et temporaires si le dépôt a été déplacé. Le serveur doit tourner.
Le script natif utilise les ressources du bundle local `build/PKwindowsManagement.app`.
Il vérifie la version 2026.09.08 et l'architecture arm64 avant de produire son archive. Pour une
nouvelle version de l'app, mettre à jour ensemble le script, le nom de l'archive et les liens.

`prepare.py` écrit les captures originales dans `sources/screenshots/`, leurs dérivés WebP et les
PNG affichés par le site dans `website/screenshots/`, l'archive locale dans `sources/downloads/`.

## Ce qui est animé

La **simulation web**, pas un enregistrement des fenêtres système : fenêtres superposées → moitiés
→ tiers → grille → maximisation → retour. Captures natives recadrées dans des conteneurs HTML,
curseur synthétique qui se déplace et se contracte au clic, sélection des boutons et changement de
légende. `renderMediaFrame(t)` exporte les géométries du même playground, en temps déterministe.
Le contenu bitmap ne se réorganise pas comme une vraie fenêtre redimensionnée. C'est annoncé dans
la page. Les médias animés sont en français ; leur légende web est bilingue.

| Export | Format | Durée / poids mesuré |
| --- | --- | --- |
| `website/videos/window-flow.mp4` | 1200 × 750, H.264, 24 fps, silencieux | 8 s · 1,54 Mo |
| `website/gifs/window-flow-wide.gif` | 960 × 600, 12 fps, boucle infinie | 8 s · 3,96 Mo |
| `sources/gifs/window-flow-compact.gif` | 480 × 300, 12 fps, boucle infinie | 8 s · 1,17 Mo |
| `sources/assets/banner-1544x500.png` | PNG | 1544 × 500 |
| `website/assets/card-1200x630.png` | PNG | 1200 × 630 |
| `sources/screenshots/*.png` | captures originales Retina | PNG, avec dérivés WebP légers dans `website/screenshots/` |

Les GIFs sont proposés par lien pour éviter leur chargement initial. Le MP4 utilise `preload=none`,
des contrôles natifs et un poster statique. La démo interactive ne tourne que sur demande et
s'arrête hors écran ou dans un onglet masqué. `prefers-reduced-motion` supprime les transitions.

## Distribution

La release Stable **2026.10.43** est construite par `.github/workflows/release.yml` depuis le tag
`v2026.10.43` : app macOS 13+, Apple Silicon (arm64), DMG versionné et archive ZIP Sparkle signée.
Le workflow signe avec le certificat Apple Development configuré ; aucun certificat Developer ID
ou ticket de notarisation n'est promis.

- **GitHub Release `v2026.10.43`** du dépôt public :
  `PKwindowsManagement_2026.10.43.dmg` et `PKwindowsManagement-app.zip`.
- **Cask Homebrew** `pk-windows-management` du tap `mondary/tap` :
  `brew install --cask mondary/tap/pk-windows-management`.
- **Miroir local** : `sources/downloads/PKwindowsManagement-2026.09.08-arm64.zip` avec sa somme
  SHA-256 dans `SHA256SUMS.txt` ; ce miroir n'est pas déployé sur le site.

La vitrine/documentation porte la version de dépôt **2026.09.11**. `CHANGELOG.md` fait foi ;
le fichier `VERSION` préexistant reste synchronisé car le script de packaging actuel le lit.
L'archive précédente n'a pas été artificiellement renommée : la version de la vitrine et celle
du bundle sont distinctes.

## Contrôles effectués

- Revue visuelle desktop, tablette et mobile : 390, 768, 1440, 1920 px, FR et EN.
- Aucun débordement horizontal dans les huit combinaisons.
- Images chargées, destinations locales répondant HTTP 200.
- Dispositions, restauration, réglage des marges, flèches clavier, thèmes Big Year.
- Choix FR/EN conservé au rechargement ; détection `es-ES, en-GB, fr-FR` → EN.
- Choix manuel fonctionnel même lorsque le stockage local lève une erreur.
- Rendu sans JavaScript inspecté ; images et playground testés en `file://`.
- MP4 lu dans le navigateur, GIF et bannière ouverts pour revue visuelle.
- Syntaxe JavaScript et `git diff --check` valides.
- Archive ZIP intègre, signature du bundle vérifiée et somme SHA-256 disponible.
- Destination Ko-fi conforme à `https://ko-fi.com/pouark` ; sa requête HTTP automatique
  reçoit un challenge Cloudflare (403), donc pas de validation HTTP 200 revendiquée pour ce tiers.

### Mesures locales

Résultats détaillés : `validation.json`. Ego Lite / Chromium, serveur Python localhost,
cache désactivé, **sans limitation CPU/réseau**, un échantillon par taille. Ces valeurs ne sont
pas une mesure de performance d'un hébergement de production ni un score Lighthouse.

| Viewport | Transfert initial | LCP | CLS |
| --- | --- | --- | --- |
| 390 px | 654 Ko | 88 ms | 0 |
| 1440 px | 547 Ko | 80 ms | 0 |

Objectifs du brief atteints dans ce contexte : initial < 1,5 Mo, LCP < 2,5 s, CLS < 0,1.
Les grandes images PNG et l'archive ne sont chargées qu'en suivant les liens.
