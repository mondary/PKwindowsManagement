#!/bin/bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$BASE/server.pid"
if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    for _ in {1..20}; do
      kill -0 "$PID" 2>/dev/null || break
      sleep 0.25
    done
  fi
  rm -f "$PID_FILE"
fi
echo "Laya server stopped."
