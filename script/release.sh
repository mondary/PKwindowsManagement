#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PKwindowsManagement"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
INSTALLED_APP="/Applications/$APP_NAME.app"

pkill -x "$APP_NAME" 2>/dev/null || true
"$ROOT_DIR/script/package_app.sh" release >/dev/null

rm -rf "$INSTALLED_APP"
ditto "$SOURCE_APP" "$INSTALLED_APP"

echo "Release installed: $INSTALLED_APP"
