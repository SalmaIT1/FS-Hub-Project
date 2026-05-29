import os
from pathlib import Path

_root = Path(__file__).resolve().parents[2]
_env_file = _root / ".env"
if _env_file.exists():
    try:
        from dotenv import load_dotenv

        load_dotenv(_env_file)
    except ImportError:
        pass

API_KEY = os.getenv("AI_API_KEY", "")
MODEL_REGISTRY_PATH = Path(os.getenv("MODEL_REGISTRY_PATH", "models"))
SERVICE_NAME = "FS-Hub AI Service"
DEFAULT_MODEL_VERSION = "heuristic-v1"

# Allow dev-only fallback when explicitly enabled
ALLOW_DEV_API_KEY = os.getenv("AI_ALLOW_DEV_KEY", "").lower() in ("1", "true", "yes")
DEV_API_KEY = os.getenv("AI_DEV_API_KEY", "dev-ai-key-change-me")
