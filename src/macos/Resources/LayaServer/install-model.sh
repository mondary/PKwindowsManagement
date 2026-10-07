#!/bin/bash
# Install/download the shared Laya weights into the standard HF cache.
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required to set up the shared Laya runtime. Install it from https://docs.astral.sh/uv/" >&2
  exit 1
fi
if [[ ! -x "$BASE/.venv/bin/python" ]]; then
  uv venv --python 3.12 "$BASE/.venv"
fi
uv pip install --python "$BASE/.venv/bin/python" laya fastapi "uvicorn[standard]"
HF_HUB_OFFLINE=0 "$BASE/.venv/bin/python" - <<'PY'
from huggingface_hub import snapshot_download
snapshot_download("convaiinnovations/laya")
print("Laya weights downloaded to the shared Hugging Face cache.")
PY
