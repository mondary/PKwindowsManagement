#!/usr/bin/env bash
# Installe la dernière build Dev publiée (release « dev ») dans /Applications
# et relance l'app. C'est exactement le zip servi par le canal Dev de Sparkle :
# un seul canal de test, la mise à jour se fait depuis l'app elle-même.
#
# Usage:
#   src/script/dev_update.sh                # installer et lancer
#   src/script/dev_update.sh --no-launch    # installer sans lancer
set -euo pipefail

APP_NAME="PKwindowsManagement"
REPO="mondary/PKwindowsManagement"
ASSET_URL="https://github.com/$REPO/releases/download/dev/${APP_NAME}-dev.zip"
INSTALL_DIR="/Applications"
APP_DIR="$INSTALL_DIR/$APP_NAME.app"

LAUNCH=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-launch) LAUNCH=0; shift ;;
    --branch) shift 2 ;;  # accepté et ignoré : un seul canal Dev
    *)
      echo "Usage: $0 [--no-launch]" >&2
      exit 2
      ;;
  esac
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "→ Télécharge la dernière build Dev publiée…"
if ! curl -fsSL "$ASSET_URL" -o "$WORK/app.zip"; then
  echo "Build Dev introuvable sur la release « dev » ($ASSET_URL)." >&2
  exit 1
fi
ditto -x -k --sequesterRsrc "$WORK/app.zip" "$WORK"

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
echo "✓ $APP_NAME v$VERSION installé (canal Dev)"

if [[ "$LAUNCH" == "1" ]]; then
  open "$APP_DIR"
  echo "✓ App lancée — ⌃⌥R ouvre la vue Rooms"
fi
