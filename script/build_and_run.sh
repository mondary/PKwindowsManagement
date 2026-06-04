#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PKwindowsManagement"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

pkill -x "$APP_NAME" 2>/dev/null || true
"$ROOT_DIR/script/package_app.sh" debug >/dev/null

/usr/bin/open -n "$APP_DIR"

if [[ "${1:-}" == "--verify" ]]; then
  sleep 1
  pgrep -x "$APP_NAME" >/dev/null
  echo "$APP_NAME launched"
fi
