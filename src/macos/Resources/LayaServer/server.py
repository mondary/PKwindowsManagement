"""Sidecar Laya partagé entre les apps PK.

Sert les décisions typées du modèle Laya (convaiinnovations/laya, Apache-2.0)
sur 127.0.0.1:8770. Les poids vivent dans le cache Hugging Face standard,
mutualisé avec toutes les autres apps PK (convention modeles-partages).

- Chargement en tâche de fond au démarrage (25-35 s), /health dit où on en est.
- Un seul forward pass à la fois : verrou autour de predict.
- HF_HUB_OFFLINE=1 : les poids sont déjà en cache, on évite les contrôles réseau.
"""

import os

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("USE_TF", "0")

import threading
from contextlib import asynccontextmanager
from typing import Any

import laya
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

MODEL_REPO = "convaiinnovations/laya"
PORT = 8770

_state: dict[str, Any] = {"agent": None, "error": None}
_lock = threading.Lock()


def _load_agent() -> None:
    try:
        agent = laya.load(MODEL_REPO)
        # Warm-up : la première passe à une forme de batch donnée compile des
        # noyaux et peut être plusieurs fois plus lente.
        agent.predict(
            "Warm-up request for the shared decision server.",
            {"warmup": {"type": "noul", "instructions": "Is this a warm-up request?"}},
        )
        _state["agent"] = agent
        print("laya: agent prêt", flush=True)
    except Exception as exc:  # noqa: BLE001
        _state["error"] = str(exc)
        print(f"laya: échec du chargement : {exc}", flush=True)


@asynccontextmanager
async def lifespan(_: FastAPI):
    threading.Thread(target=_load_agent, daemon=True).start()
    yield


app = FastAPI(title="Laya sidecar", version="1.0", lifespan=lifespan)


class PredictBody(BaseModel):
    state: Any
    questions: dict[str, Any]
    lang: str | None = None


@app.get("/health")
def health() -> dict:
    if _state["agent"] is not None:
        return {"ready": True, "model": MODEL_REPO}
    if _state["error"] is not None:
        return {"ready": False, "error": _state["error"]}
    return {"ready": False, "loading": True}


@app.post("/predict")
def predict(body: PredictBody) -> dict:
    agent = _state["agent"]
    if agent is None:
        detail = _state["error"] or "model still loading"
        raise HTTPException(status_code=503, detail=detail)
    kwargs = {}
    if body.lang:
        kwargs["lang"] = body.lang
    with _lock:
        return agent.predict(body.state, body.questions, **kwargs)


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=PORT, log_level="warning")
