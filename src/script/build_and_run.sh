#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_NAME="PKwindowsManagement"
APP_DIR="$ROOT_DIR/release/$APP_NAME.app"

pkill -x "$APP_NAME" 2>/dev/null || true
"$ROOT_DIR/src/script/package_app.sh" debug >/dev/null

/usr/bin/open -n "$APP_DIR"

if [[ "${1:-}" == "--verify" ]]; then
  for _ in {1..5}; do
    sleep 1
    if ! pgrep -x "$APP_NAME" >/dev/null; then
      echo "$APP_NAME stopped during startup" >&2
      exit 1
    fi
  done
  echo "$APP_NAME launched"
fi
