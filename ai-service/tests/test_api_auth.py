"""API authentication tests for FS-Hub AI service."""

import os

import pytest
from fastapi.testclient import TestClient

from main import app


@pytest.fixture
def fresh_client() -> TestClient:
    return TestClient(app)


def test_health_is_public(fresh_client: TestClient) -> None:
    response = fresh_client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_v1_requires_api_key(fresh_client: TestClient) -> None:
    response = fresh_client.get("/v1/models/status")
    assert response.status_code == 403


def test_v1_accepts_valid_api_key(fresh_client: TestClient) -> None:
    response = fresh_client.get(
        "/v1/models/status",
        headers={"X-API-Key": os.environ["AI_API_KEY"]},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "success"


def test_invalid_api_key_rejected(fresh_client: TestClient) -> None:
    response = fresh_client.post(
        "/v1/predict/project-delay",
        headers={"X-API-Key": "wrong-key"},
        json={
            "features": {
                "total_tasks": 5,
                "completed_tasks": 2,
                "delayed_tasks": 1,
            }
        },
    )
    assert response.status_code == 403


def test_missing_api_key_on_legacy_route(fresh_client: TestClient) -> None:
    response = fresh_client.post(
        "/ai/predict-delay",
        json={"total_tasks": 5, "completed_tasks": 2},
    )
    assert response.status_code == 403
