"""HTTP integration tests for prediction endpoints."""

from fastapi.testclient import TestClient


def test_project_delay_v1_returns_confidence_fields(
    client: TestClient, api_headers: dict[str, str]
) -> None:
    response = client.post(
        "/v1/predict/project-delay",
        headers=api_headers,
        json={
            "project_id": 1,
            "features": {
                "total_tasks": 20,
                "completed_tasks": 8,
                "delayed_tasks": 5,
                "team_availability": 0.75,
                "days_remaining": 10,
            },
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "success"
    data = body["data"]
    assert 0 <= data["delay_probability"] <= 1
    assert data["risk_band"] in ("LOW", "MEDIUM", "HIGH", "CRITICAL")
    assert "explanation" in data


def test_payment_risk_v1(client: TestClient, api_headers: dict[str, str]) -> None:
    response = client.post(
        "/v1/predict/payment-risk",
        headers=api_headers,
        json={
            "client_id": 42,
            "features": {
                "total_amount": 10000,
                "paid_amount": 2000,
                "late_payments": 3,
                "avg_payment_delay": 20,
                "client_outstanding": 5000,
            },
        },
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["risk_level"] in ("LOW", "MEDIUM", "HIGH")


def test_malformed_payload_returns_422(
    client: TestClient, api_headers: dict[str, str]
) -> None:
    response = client.post(
        "/v1/predict/project-delay",
        headers=api_headers,
        json={"features": "not-an-object"},
    )
    assert response.status_code == 422


def test_expense_anomalies_endpoint(
    client: TestClient, api_headers: dict[str, str]
) -> None:
    response = client.post(
        "/v1/detect/expense-anomalies",
        headers=api_headers,
        json={
            "expenses": [
                {"id": 1, "montant": 50},
                {"id": 2, "montant": 100000},
            ]
        },
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["scanned"] == 2


def test_dashboard_analytics(client: TestClient, api_headers: dict[str, str]) -> None:
    response = client.get("/v1/dashboard/analytics", headers=api_headers)
    assert response.status_code == 200
    assert "capabilities" in response.json()["data"]
