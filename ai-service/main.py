from fastapi import FastAPI, HTTPException, Security
from fastapi.security import APIKeyHeader
from pydantic import BaseModel
from services.prediction_service import PredictionService
import uvicorn
import os

app = FastAPI(title="FS-Hub AI Service")

API_KEY_NAME = "X-API-Key"
# P0-3 FIX: Removed insecure hardcoded fallback default.
# Service will refuse to start if AI_API_KEY is not explicitly provided.
API_KEY = os.getenv("AI_API_KEY")
if not API_KEY:
    raise RuntimeError(
        "[SECURITY] AI_API_KEY environment variable is required but not set. "
        "Set it in your .env file or container environment before starting the service."
    )

api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=True)

async def get_api_key(api_header: str = Security(api_key_header)):
    if api_header != API_KEY:
        raise HTTPException(status_code=403, detail="Could not validate AI credentials")
    return api_header

# Request Models
class ProjectDelayRequest(BaseModel):
    total_tasks: int
    completed_tasks: int
    delayed_tasks: int
    team_availability: float # 0.0 to 1.0
    days_remaining: int

class DurationRequest(BaseModel):
    nb_tasks: int
    avg_task_duration: float
    team_size: int

class ClientRiskRequest(BaseModel):
    total_amount: float
    paid_amount: float
    late_payments: int
    avg_payment_delay: float

class HRAnalysisRequest(BaseModel):
    total_days: int
    absent_days: int
    late_days: int
    completed_tasks: int
    assigned_tasks: int

@app.post("/ai/predict-delay", dependencies=[Security(get_api_key)])
async def predict_delay(req: ProjectDelayRequest):
    try:
        score = PredictionService.predict_project_delay(
            req.total_tasks, req.completed_tasks, req.delayed_tasks, 
            req.team_availability, req.days_remaining
        )
        return {"status": "success", "data": {"risk_score": score}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ai/estimate-duration", dependencies=[Security(get_api_key)])
async def estimate_duration(req: DurationRequest):
    try:
        days = PredictionService.estimate_duration(
            req.nb_tasks, req.avg_task_duration, req.team_size
        )
        return {"status": "success", "data": {"estimated_days_remaining": days}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ai/client-risk", dependencies=[Security(get_api_key)])
async def client_risk(req: ClientRiskRequest):
    try:
        level = PredictionService.analyze_client_risk(
            req.total_amount, req.paid_amount, req.late_payments, req.avg_payment_delay
        )
        return {"status": "success", "data": {"risk_level": level}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ai/employee-performance", dependencies=[Security(get_api_key)])
async def employee_performance(req: HRAnalysisRequest):
    try:
        metrics = PredictionService.analyze_hr_performance(
            req.total_days, req.absent_days, req.late_days, 
            req.completed_tasks, req.assigned_tasks
        )
        return {"status": "success", "data": metrics}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# P3-6 FIX: Health check for Docker liveness/readiness probes.
@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "FS-Hub AI Service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
