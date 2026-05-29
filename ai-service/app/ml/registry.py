"""Model registry — loads trained joblib artifacts when present, else heuristic."""

from pathlib import Path
from typing import Any, Optional

from app.core.config import DEFAULT_MODEL_VERSION, MODEL_REGISTRY_PATH
from app.ml.heuristic import HeuristicEngine

_loaded: dict[str, Any] = {}


def get_engine(problem_code: str) -> Any:
    if problem_code in _loaded:
        return _loaded[problem_code]

    model_path = MODEL_REGISTRY_PATH / problem_code / "current" / "model.joblib"
    if model_path.exists():
        try:
            import joblib

            artifact = joblib.load(model_path)
            _loaded[problem_code] = artifact
            return artifact
        except Exception as e:
            print(f"[registry] Failed to load {model_path}: {e}")

    _loaded[problem_code] = HeuristicEngine
    return HeuristicEngine


def model_info(problem_code: str) -> dict:
    model_path = MODEL_REGISTRY_PATH / problem_code / "current" / "model.joblib"
    if model_path.exists():
        version_file = MODEL_REGISTRY_PATH / problem_code / "current" / "version.txt"
        version = version_file.read_text().strip() if version_file.exists() else "trained"
        return {"name": problem_code, "version": version, "type": "joblib"}
    return {"name": problem_code, "version": DEFAULT_MODEL_VERSION, "type": "heuristic"}


def all_models_status() -> dict:
    problems = [
        "project_delay",
        "completion_time",
        "payment_risk",
        "employee_performance",
        "expense_anomaly",
    ]
    return {p: model_info(p) for p in problems}
