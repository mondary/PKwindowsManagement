#!/bin/bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$BASE/server.pid"
LOG_FILE="$BASE/server.log"
if curl -fsS --max-time 2 http://127.0.0.1:8770/health >/dev/null 2>&1; then
  echo "Laya server already running."
  exit 0
fi
if [[ ! -x "$BASE/.venv/bin/python" ]]; then
  echo "Laya runtime is not installed. Download the shared model first." >&2
  exit 1
fi
nohup "$BASE/.venv/bin/python" "$BASE/server.py" >>"$LOG_FILE" 2>&1 </dev/null &
echo $! > "$PID_FILE"
echo "Laya server starting on 127.0.0.1:8770. First load can take 25–35 seconds."
