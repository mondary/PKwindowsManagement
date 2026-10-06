#!/usr/bin/env bash
# Installe la dernière build CI réussie d'une branche dans /Applications et
# relance l'app. Boucle de test « push → CI → je teste » sans builder localement
# (utile tant que le CLT seul ne compile pas SwiftUI).
#
# Usage:
#   src/script/dev_update.sh                # branche git courante
#   src/script/dev_update.sh --branch main  # une autre branche
#   src/script/dev_update.sh --no-launch    # installer sans lancer
set -euo pipefail

APP_NAME="PKwindowsManagement"
ARTIFACT_NAME="$APP_NAME-macos"
INSTALL_DIR="/Applications"
APP_DIR="$INSTALL_DIR/$APP_NAME.app"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
LAUNCH=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --no-launch) LAUNCH=0; shift ;;
    *)
      echo "Usage: $0 [--branch nom] [--no-launch]" >&2
      exit 2
      ;;
  esac
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "→ Recherche de la dernière run CI réussie sur « $BRANCH »…"
RUN_ID="$(gh run list --workflow "Build macOS app" --branch "$BRANCH" --status success --limit 1 --json databaseId --jq '.[0].databaseId')"
if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
  echo "Aucune run « Build macOS app » réussie trouvée sur « $BRANCH »." >&2
  exit 1
fi
echo "  run CI #$RUN_ID"

gh run download "$RUN_ID" -n "$ARTIFACT_NAME" -D "$WORK"
APP_ZIP="$(find "$WORK" -name '*.app.zip' -maxdepth 2 | head -1)"
if [[ -z "$APP_ZIP" ]]; then
  echo "Artifact $ARTIFACT_NAME introuvable dans la run #$RUN_ID." >&2
  exit 1
fi
ditto -x -k --sequesterRsrc "$APP_ZIP" "$WORK"

# Quitter poliment l'app si elle tourne (le pkill n'est qu'un garde-fou).
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo "→ Quitte ${APP_NAME}…"
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  for _ in {1..20}; do
    pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
    sleep 0.25
  done
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

echo "→ Installation dans ${APP_DIR}…"
rm -rf "$APP_DIR"
ditto "$WORK/$APP_NAME.app" "$APP_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist" 2>/dev/null || echo '?')"
echo "✓ $APP_NAME v$VERSION installé (run CI #$RUN_ID, branche $BRANCH)"

if [[ "$LAUNCH" == "1" ]]; then
  open "$APP_DIR"
  echo "✓ App lancée — ⌃⌥R ouvre la vue Rooms"
fi
