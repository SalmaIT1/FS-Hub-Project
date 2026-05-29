"""Pydantic schema validation tests."""

import pytest
from pydantic import ValidationError

from app.schemas.predictions import (
    ProjectDelayRequest,
    PaymentRiskRequest,
    ExpenseAnomalyRequest,
)


def test_project_delay_requires_features() -> None:
    with pytest.raises(ValidationError):
        ProjectDelayRequest.model_validate({})


def test_project_delay_invalid_feature_type_rejected() -> None:
    with pytest.raises(ValidationError):
        ProjectDelayRequest.model_validate(
            {"features": {"team_availability": "not-a-float"}}
        )


def test_payment_risk_accepts_defaults() -> None:
    req = PaymentRiskRequest.model_validate(
        {"features": {"total_amount": 1000, "paid_amount": 500}}
    )
    assert req.features.late_payments == 0


def test_expense_anomaly_empty_list() -> None:
    req = ExpenseAnomalyRequest.model_validate({"expenses": []})
    assert req.expenses == []
