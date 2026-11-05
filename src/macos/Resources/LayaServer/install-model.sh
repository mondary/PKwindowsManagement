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
# Reuse the token the user already configured: environment first, then the
# standard huggingface-cli login file. Never ask for it again in the UI.
TOKEN="${HF_TOKEN:-${HUGGING_FACE_HUB_TOKEN:-}}"
if [[ -z "$TOKEN" && -f "$HOME/.cache/huggingface/token" ]]; then
  TOKEN="$(cat "$HOME/.cache/huggingface/token")"
fi
if [[ -n "$TOKEN" ]]; then export HF_TOKEN="$TOKEN"; fi
HF_HUB_OFFLINE=0 "$BASE/.venv/bin/python" - <<'PY'
from huggingface_hub import snapshot_download
from huggingface_hub.utils import GatedRepoError, RepositoryNotFoundError, HfHubHTTPError
try:
    snapshot_download("convaiinnovations/laya")
    print("Laya weights downloaded to the shared Hugging Face cache.")
except GatedRepoError:
    print("GATED_REPO https://huggingface.co/convaiinnovations/laya")
    raise SystemExit(3)
except RepositoryNotFoundError:
    print("GATED_REPO https://huggingface.co/convaiinnovations/laya")
    raise SystemExit(3)
except HfHubHTTPError as error:
    if getattr(error.response, "status_code", None) in (401, 403):
        print("GATED_REPO https://huggingface.co/convaiinnovations/laya")
        raise SystemExit(3)
    raise
PY
