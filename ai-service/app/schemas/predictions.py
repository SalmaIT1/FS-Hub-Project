from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class FeatureContribution(BaseModel):
    feature: str
    impact: float
    value: Any
    label_fr: Optional[str] = None


class Explanation(BaseModel):
    summary_fr: str
    top_features: List[FeatureContribution] = Field(default_factory=list)
    shap_base_value: Optional[float] = None


class ModelInfo(BaseModel):
    name: str
    version: str = "heuristic-v1"


class ProjectDelayFeatures(BaseModel):
    total_tasks: int = 0
    completed_tasks: int = 0
    delayed_tasks: int = 0
    team_availability: float = 0.85
    days_remaining: int = 14
    priorite: str = "Moyenne"
    team_size: int = 1
    client_outstanding: float = 0.0


class ProjectDelayRequest(BaseModel):
    project_id: Optional[int] = None
    features: ProjectDelayFeatures


class CompletionFeatures(BaseModel):
    nb_tasks: int
    avg_task_duration: float = 8.0
    team_size: int = 1


class CompletionTimeRequest(BaseModel):
    project_id: Optional[int] = None
    features: CompletionFeatures


class PaymentRiskFeatures(BaseModel):
    total_amount: float = 0.0
    paid_amount: float = 0.0
    late_payments: int = 0
    avg_payment_delay: float = 0.0
    client_outstanding: float = 0.0


class PaymentRiskRequest(BaseModel):
    client_id: Optional[int] = None
    invoice_id: Optional[int] = None
    features: PaymentRiskFeatures


class EmployeePerformanceFeatures(BaseModel):
    total_days: int = 22
    absent_days: int = 0
    late_days: int = 0
    completed_tasks: int = 0
    assigned_tasks: int = 0
    active_projects: int = 0


class EmployeePerformanceRequest(BaseModel):
    employee_id: Optional[str] = None
    features: EmployeePerformanceFeatures


class ExpenseItem(BaseModel):
    id: Any
    expense_type: str = "company"
    montant: Optional[float] = 0.0
    category_id: Optional[int] = None
    status: Optional[str] = None


class ExpenseAnomalyRequest(BaseModel):
    expenses: List[ExpenseItem] = Field(default_factory=list)
    amount_stats: Optional[Dict[str, float]] = None


# Legacy flat request models (backward compatible)
class LegacyProjectDelayRequest(BaseModel):
    total_tasks: int
    completed_tasks: int
    delayed_tasks: int
    team_availability: float
    days_remaining: int


class LegacyDurationRequest(BaseModel):
    nb_tasks: int
    avg_task_duration: float
    team_size: int


class LegacyClientRiskRequest(BaseModel):
    total_amount: float
    paid_amount: float
    late_payments: int
    avg_payment_delay: float


class LegacyHRAnalysisRequest(BaseModel):
    total_days: int
    absent_days: int
    late_days: int
    completed_tasks: int
    assigned_tasks: int
