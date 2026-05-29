from fastapi import HTTPException, Security
from fastapi.security import APIKeyHeader

from app.core.config import ALLOW_DEV_API_KEY, API_KEY, DEV_API_KEY

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=True)


def resolve_api_key() -> str:
    if API_KEY:
        return API_KEY
    if ALLOW_DEV_API_KEY:
        return DEV_API_KEY
    raise RuntimeError(
        "[SECURITY] AI_API_KEY is required. Set AI_API_KEY or AI_ALLOW_DEV_KEY=true for local dev."
    )


async def verify_api_key(api_header: str = Security(api_key_header)) -> str:
    expected = resolve_api_key()
    if api_header != expected:
        raise HTTPException(status_code=403, detail="Could not validate AI credentials")
    return api_header
