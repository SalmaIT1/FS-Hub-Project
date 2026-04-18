from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from services.prediction_service import PredictionService
import uvicorn

app = FastAPI(title="FS-Hub AI Service")

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

@app.post("/ai/predict-delay")
async def predict_delay(req: ProjectDelayRequest):
    try:
        score = PredictionService.predict_project_delay(
            req.total_tasks, req.completed_tasks, req.delayed_tasks, 
            req.team_availability, req.days_remaining
        )
        return {"status": "success", "data": {"risk_score": score}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ai/estimate-duration")
async def estimate_duration(req: DurationRequest):
    try:
        days = PredictionService.estimate_duration(
            req.nb_tasks, req.avg_task_duration, req.team_size
        )
        return {"status": "success", "data": {"estimated_days_remaining": days}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ai/client-risk")
async def client_risk(req: ClientRiskRequest):
    try:
        level = PredictionService.analyze_client_risk(
            req.total_amount, req.paid_amount, req.late_payments, req.avg_payment_delay
        )
        return {"status": "success", "data": {"risk_level": level}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ai/employee-performance")
async def employee_performance(req: HRAnalysisRequest):
    try:
        metrics = PredictionService.analyze_hr_performance(
            req.total_days, req.absent_days, req.late_days, 
            req.completed_tasks, req.assigned_tasks
        )
        return {"status": "success", "data": metrics}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
