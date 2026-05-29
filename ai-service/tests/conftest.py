"""Shared pytest fixtures for FS-Hub AI service."""

import os

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("AI_ALLOW_DEV_KEY", "true")
os.environ.setdefault("AI_API_KEY", "test-key")

from main import app  # noqa: E402


@pytest.fixture(scope="session")
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def api_headers() -> dict[str, str]:
    return {"X-API-Key": os.environ["AI_API_KEY"]}
