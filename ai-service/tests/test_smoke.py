"""Smoke tests for FS-Hub AI service (run: pytest tests/ -q)."""

import os

os.environ.setdefault("AI_ALLOW_DEV_KEY", "true")
os.environ.setdefault("AI_API_KEY", "test-key")

from app.ml.heuristic import HeuristicEngine  # noqa: E402


def test_project_delay_has_explanation():
    result = HeuristicEngine.predict_project_delay(
        {
            "total_tasks": 20,
            "completed_tasks": 8,
            "delayed_tasks": 5,
            "team_availability": 0.75,
            "days_remaining": 10,
        }
    )
    assert 0 <= result["delay_probability"] <= 1
    assert result["risk_band"] in ("LOW", "MEDIUM", "HIGH", "CRITICAL")
    assert "summary_fr" in result["explanation"]


def test_payment_risk_levels():
    result = HeuristicEngine.predict_payment_risk(
        {
            "total_amount": 10000,
            "paid_amount": 2000,
            "late_payments": 3,
            "avg_payment_delay": 20,
            "client_outstanding": 5000,
        }
    )
    assert result["risk_level"] in ("LOW", "MEDIUM", "HIGH")
    assert result["late_payment_probability"] > 0.5


def test_expense_anomaly_detection():
    expenses = [
        {"id": 1, "montant": 50},
        {"id": 2, "montant": 55},
        {"id": 3, "montant": 48},
        {"id": 4, "montant": 52},
        {"id": 5, "montant": 100000},
    ]
    data = HeuristicEngine.detect_expense_anomalies(expenses, None)
    assert data["scanned"] == 5
    assert len(data["anomalies"]) >= 1
