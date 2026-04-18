import numpy as np

class PredictionService:
    @staticmethod
    def predict_project_delay(total_tasks, completed_tasks, delayed_tasks, team_availability, days_remaining):
        """
        Predicts delay probability using a logistic-like computation.
        """
        if total_tasks == 0: return 0.0
        
        # Features weighting
        progress_gap = (total_tasks - completed_tasks) / total_tasks
        delay_ratio = delayed_tasks / total_tasks if total_tasks > 0 else 0
        urgency = 1.0 / (days_remaining if days_remaining > 0 else 0.1)
        
        # Logistic formula approximation
        z = (3.0 * progress_gap) + (5.0 * delay_ratio) + (2.0 * urgency) - (2.0 * team_availability)
        risk_score = 1 / (1 + np.exp(-z))
        
        return float(round(risk_score, 2))

    @staticmethod
    def estimate_duration(nb_tasks, avg_task_duration, team_size):
        """
        Estimates remaining days using Linear Regression logic.
        """
        if team_size <= 0: return 0
        # Basic linear model: Y = (Tasks * Duration) / Capacity
        estimated_days = (nb_tasks * avg_task_duration) / (team_size * 0.8) # 0.8 factor for overhead
        return int(round(estimated_days))

    @staticmethod
    def analyze_client_risk(total_amount, paid_amount, late_payments, avg_payment_delay):
        """
        Determines client risk level.
        """
        payment_ratio = paid_amount / total_amount if total_amount > 0 else 1.0
        
        score = (payment_ratio * 40) - (late_payments * 10) - (avg_payment_delay * 0.5)
        
        if score > 30: return "LOW"
        if score > 10: return "MEDIUM"
        return "HIGH"

    @staticmethod
    def analyze_hr_performance(total_days, absent_days, late_days, completed_tasks, assigned_tasks):
        """
        Calculates HR performance and absence metrics.
        """
        if total_days <= 0: return {"performance_score": 0, "absence_rate": 0}
        
        absence_rate = (absent_days / total_days) * 100
        productivity = (completed_tasks / assigned_tasks) * 100 if assigned_tasks > 0 else 0
        punctuality = max(0, 100 - (late_days * 5))
        
        performance_score = (productivity * 0.6) + (punctuality * 0.4)
        
        return {
            "performance_score": float(round(performance_score, 2)),
            "absence_rate": float(round(absence_rate, 2))
        }
