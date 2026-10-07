#!/bin/bash
# Sidecar Laya partagé entre les apps PK.
# Poids : cache Hugging Face standard (~/.cache/huggingface/hub) — déjà présent,
# jamais de copie par app (convention modeles-partages).
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -d .venv ]]; then
  echo "→ Création du venv (première fois)…"
  uv venv --python 3.12
  uv pip install laya fastapi "uvicorn[standard]"
fi

# Complète le snapshot de la révision main si besoin (dédupe par blobs :
# ce qui est déjà en cache n'est pas retéléchargé).
if ! .venv/bin/python - <<'PY'
from huggingface_hub import snapshot_download
snapshot_download("convaiinnovations/laya")
print("snapshot main complet")
PY
then
  echo "Impossible de compléter le snapshot Hugging Face." >&2
  exit 1
fi

exec .venv/bin/python server.py
