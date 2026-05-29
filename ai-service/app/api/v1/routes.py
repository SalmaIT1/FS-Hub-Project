from fastapi import APIRouter, Depends, HTTPException

from app.core.config import DEFAULT_MODEL_VERSION, SERVICE_NAME
from app.core.security import verify_api_key
from app.ml.heuristic import HeuristicEngine
from app.ml.registry import all_models_status, get_engine, model_info
from app.schemas.predictions import (
    CompletionTimeRequest,
    EmployeePerformanceRequest,
    ExpenseAnomalyRequest,
    LegacyClientRiskRequest,
    LegacyDurationRequest,
    LegacyHRAnalysisRequest,
    LegacyProjectDelayRequest,
    PaymentRiskRequest,
    ProjectDelayRequest,
)

router = APIRouter(prefix="/v1", dependencies=[Depends(verify_api_key)])


def _response(data: dict, problem: str) -> dict:
    info = model_info(problem)
    return {"status": "success", "model": info, "data": data}


@router.get("/models/status")
async def models_status():
    return {"status": "success", "service": SERVICE_NAME, "models": all_models_status()}


@router.post("/predict/project-delay")
async def predict_project_delay(req: ProjectDelayRequest):
    try:
        engine = get_engine("project_delay")
        if engine is HeuristicEngine:
            data = engine.predict_project_delay(req.features.model_dump())
        else:
            data = engine.predict(req.features.model_dump())
        return _response(data, "project_delay")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post("/predict/completion-time")
async def predict_completion_time(req: CompletionTimeRequest):
    try:
        data = HeuristicEngine.estimate_completion_time(req.features.model_dump())
        return _response(data, "completion_time")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post("/predict/payment-risk")
async def predict_payment_risk(req: PaymentRiskRequest):
    try:
        data = HeuristicEngine.predict_payment_risk(req.features.model_dump())
        return _response(data, "payment_risk")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post("/predict/employee-performance")
async def predict_employee_performance(req: EmployeePerformanceRequest):
    try:
        data = HeuristicEngine.analyze_employee_performance(req.features.model_dump())
        return _response(data, "employee_performance")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post("/detect/expense-anomalies")
async def detect_expense_anomalies(req: ExpenseAnomalyRequest):
    try:
        expenses = [e.model_dump() for e in req.expenses]
        data = HeuristicEngine.detect_expense_anomalies(expenses, req.amount_stats)
        return _response(data, "expense_anomaly")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.get("/dashboard/analytics")
async def dashboard_analytics():
    return {
        "status": "success",
        "data": {
            "models": all_models_status(),
            "capabilities": [
                "project_delay",
                "completion_time",
                "payment_risk",
                "employee_performance",
                "expense_anomaly",
            ],
            "default_version": DEFAULT_MODEL_VERSION,
        },
    }


# ── Legacy routes (backward compatible with Shelf integration) ──────────────
legacy = APIRouter(dependencies=[Depends(verify_api_key)])


@legacy.post("/ai/predict-delay")
async def legacy_predict_delay(req: LegacyProjectDelayRequest):
    data = HeuristicEngine.predict_project_delay(req.model_dump())
    return {"status": "success", "data": {"risk_score": data["delay_probability"], **data}}


@legacy.post("/ai/estimate-duration")
async def legacy_estimate_duration(req: LegacyDurationRequest):
    data = HeuristicEngine.estimate_completion_time(req.model_dump())
    return {"status": "success", "data": data}


@legacy.post("/ai/client-risk")
async def legacy_client_risk(req: LegacyClientRiskRequest):
    data = HeuristicEngine.predict_payment_risk(req.model_dump())
    return {"status": "success", "data": {"risk_level": data["risk_level"], **data}}


@legacy.post("/ai/employee-performance")
async def legacy_employee_performance(req: LegacyHRAnalysisRequest):
    data = HeuristicEngine.analyze_employee_performance(req.model_dump())
    return {"status": "success", "data": data}
