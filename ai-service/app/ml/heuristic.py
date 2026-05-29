"""Heuristic baselines — production fallback until trained models are promoted."""

import numpy as np

FEATURE_LABELS_FR = {
    "delayed_task_ratio": "Tâches en retard (>7j)",
    "progress_gap": "Écart de progression",
    "days_remaining": "Jours avant échéance",
    "team_availability": "Disponibilité équipe",
    "urgency": "Urgence calendaire",
    "payment_ratio": "Ratio de paiement",
    "late_payments": "Factures en retard",
    "avg_payment_delay": "Retard moyen (jours)",
    "client_outstanding": "Solde client dû",
    "open_tasks": "Tâches ouvertes",
    "team_size": "Taille équipe",
    "absence_rate": "Taux d'absence",
    "productivity": "Productivité tâches",
}


def risk_band(probability: float) -> str:
    if probability >= 0.75:
        return "CRITICAL"
    if probability >= 0.5:
        return "HIGH"
    if probability >= 0.35:
        return "MEDIUM"
    return "LOW"


class HeuristicEngine:
    @staticmethod
    def predict_project_delay(features: dict) -> dict:
        total_tasks = max(features.get("total_tasks", 0), 0)
        completed_tasks = features.get("completed_tasks", 0)
        delayed_tasks = features.get("delayed_tasks", 0)
        team_availability = features.get("team_availability", 0.85)
        days_remaining = features.get("days_remaining", 14)

        if total_tasks == 0:
            probability = 0.0
            contributions = []
        else:
            progress_gap = (total_tasks - completed_tasks) / total_tasks
            delay_ratio = delayed_tasks / total_tasks
            urgency = 1.0 / max(days_remaining, 1)
            z = (3.0 * progress_gap) + (5.0 * delay_ratio) + (2.0 * urgency) - (
                2.0 * team_availability
            )
            probability = float(1 / (1 + np.exp(-z)))
            contributions = [
                ("delayed_task_ratio", 0.35 * delay_ratio, delay_ratio),
                ("progress_gap", 0.30 * progress_gap, progress_gap),
                ("days_remaining", 0.20 * (1 / max(days_remaining, 1)), days_remaining),
                ("team_availability", -0.15 * team_availability, team_availability),
            ]

        from app.ml.explain import build_explanation

        explanation = build_explanation(
            probability,
            contributions,
            summary_template="Risque de retard estimé à {pct}% — principalement lié à {top}.",
        )

        return {
            "delay_probability": round(probability, 4),
            "risk_band": risk_band(probability),
            "confidence": round(min(0.95, 0.5 + abs(probability - 0.5)), 4),
            "explanation": explanation,
        }

    @staticmethod
    def estimate_completion_time(features: dict) -> dict:
        nb_tasks = features.get("nb_tasks", 0)
        avg_task_duration = features.get("avg_task_duration", 8.0)
        team_size = max(features.get("team_size", 1), 1)
        estimated_days = int(round((nb_tasks * avg_task_duration) / (team_size * 0.8)))
        return {
            "estimated_days_remaining": max(estimated_days, 0),
            "confidence": 0.7,
            "explanation": {
                "summary_fr": f"Estimation basée sur {nb_tasks} tâches ouvertes et {team_size} membre(s).",
                "top_features": [
                    {
                        "feature": "open_tasks",
                        "impact": 0.5,
                        "value": nb_tasks,
                        "label_fr": FEATURE_LABELS_FR["open_tasks"],
                    },
                    {
                        "feature": "team_size",
                        "impact": -0.3,
                        "value": team_size,
                        "label_fr": FEATURE_LABELS_FR["team_size"],
                    },
                ],
            },
        }

    @staticmethod
    def predict_payment_risk(features: dict) -> dict:
        total_amount = features.get("total_amount", 0.0)
        paid_amount = features.get("paid_amount", 0.0)
        late_payments = features.get("late_payments", 0)
        avg_payment_delay = features.get("avg_payment_delay", 0.0)
        client_outstanding = features.get("client_outstanding", 0.0)

        payment_ratio = paid_amount / total_amount if total_amount > 0 else 1.0
        score = (payment_ratio * 40) - (late_payments * 10) - (avg_payment_delay * 0.5)

        if score > 30:
            risk_level = "LOW"
            late_prob = 0.15
        elif score > 10:
            risk_level = "MEDIUM"
            late_prob = 0.45
        else:
            risk_level = "HIGH"
            late_prob = 0.78

        if client_outstanding > 50000:
            late_prob = min(0.95, late_prob + 0.1)
            if risk_level == "LOW":
                risk_level = "MEDIUM"

        from app.ml.explain import build_explanation

        explanation = build_explanation(
            late_prob,
            [
                ("payment_ratio", 0.3 * payment_ratio, payment_ratio),
                ("late_payments", 0.35 * min(late_payments, 5) / 5, late_payments),
                ("avg_payment_delay", 0.2 * min(avg_payment_delay, 60) / 60, avg_payment_delay),
                ("client_outstanding", 0.15 * min(client_outstanding, 100000) / 100000, client_outstanding),
            ],
            summary_template="Probabilité de retard de paiement {pct}% — facteur principal : {top}.",
        )

        return {
            "risk_level": risk_level,
            "late_payment_probability": round(late_prob, 4),
            "expected_days_to_pay": int(30 + avg_payment_delay),
            "confidence": 0.75,
            "explanation": explanation,
        }

    @staticmethod
    def analyze_employee_performance(features: dict) -> dict:
        total_days = max(features.get("total_days", 1), 1)
        absent_days = features.get("absent_days", 0)
        late_days = features.get("late_days", 0)
        completed_tasks = features.get("completed_tasks", 0)
        assigned_tasks = features.get("assigned_tasks", 0)
        active_projects = features.get("active_projects", 0)

        absence_rate = (absent_days / total_days) * 100
        productivity = (completed_tasks / assigned_tasks) * 100 if assigned_tasks > 0 else 0
        punctuality = max(0, 100 - (late_days * 5))
        performance_score = (productivity * 0.6) + (punctuality * 0.4)
        workload_index = min(100, active_projects * 25 + assigned_tasks * 2)

        return {
            "performance_score": round(performance_score, 2),
            "absence_rate": round(absence_rate, 2),
            "workload_index": round(workload_index, 2),
            "confidence": 0.72,
            "explanation": {
                "summary_fr": f"Score performance {performance_score:.0f}/100 — productivité {productivity:.0f}%.",
                "top_features": [
                    {
                        "feature": "productivity",
                        "impact": 0.6,
                        "value": round(productivity, 1),
                        "label_fr": FEATURE_LABELS_FR["productivity"],
                    },
                    {
                        "feature": "absence_rate",
                        "impact": -0.25,
                        "value": round(absence_rate, 1),
                        "label_fr": FEATURE_LABELS_FR["absence_rate"],
                    },
                ],
            },
        }

    @staticmethod
    def detect_expense_anomalies(expenses: list, amount_stats: dict | None) -> dict:
        if not expenses:
            return {"anomalies": [], "scanned": 0}

        amounts = [float(e.get("montant") or 0) for e in expenses if float(e.get("montant") or 0) > 0]
        if not amounts:
            return {"anomalies": [], "scanned": len(expenses)}

        sorted_amt = sorted(amounts)
        median = sorted_amt[len(sorted_amt) // 2]
        deviations = [abs(a - median) for a in amounts]
        mad = sorted(deviations)[len(deviations) // 2] or max(median * 0.1, 1.0)
        # Median + 3*MAD resists outlier skew better than mean + std
        threshold = median + 3.0 * mad
        if amount_stats and "mean" in amount_stats:
            ext_mean = float(amount_stats["mean"])
            ext_std = float(amount_stats.get("std", mad))
            threshold = max(threshold, ext_mean + 2.5 * ext_std)

        anomalies = []
        for exp in expenses:
            montant = float(exp.get("montant") or 0)
            is_outlier = montant >= threshold and montant > median * 3 and montant > 0
            if is_outlier:
                anomalies.append(
                    {
                        "expense_id": exp.get("id"),
                        "expense_type": exp.get("expense_type"),
                        "anomaly_score": round(min(1.0, montant / (threshold + 1)), 4),
                        "reason_fr": f"Montant {montant:.2f} supérieur au seuil statistique ({threshold:.2f}).",
                        "montant": montant,
                    }
                )

        return {"anomalies": anomalies, "scanned": len(expenses), "threshold": round(threshold, 2)}
