"""
FS-Hub AI Decision Support Service — entry point.
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.routes import legacy, router as v1_router
from app.core.config import SERVICE_NAME
from app.core.security import resolve_api_key

# Validate API key configuration at startup
resolve_api_key()


@asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"[{SERVICE_NAME}] Models: ready (heuristic + optional joblib registry)")
    yield


app = FastAPI(title=SERVICE_NAME, version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["X-API-Key", "Content-Type"],
)

app.include_router(v1_router)
app.include_router(legacy)


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": SERVICE_NAME}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=False)
