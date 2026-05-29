from app.ml.heuristic import FEATURE_LABELS_FR


def build_explanation(
    score: float,
    contributions: list,
    summary_template: str = "Score {pct}% — {top}.",
) -> dict:
    """Build manager-facing explanation from weighted feature contributions."""
    sorted_contribs = sorted(contributions, key=lambda x: abs(x[1]), reverse=True)
    top_features = []
    for feature, impact, value in sorted_contribs[:5]:
        top_features.append(
            {
                "feature": feature,
                "impact": round(float(impact), 4),
                "value": value,
                "label_fr": FEATURE_LABELS_FR.get(feature, feature),
            }
        )

    top_label = top_features[0]["label_fr"] if top_features else "les indicateurs projet"
    pct = int(round(score * 100))
    summary_fr = summary_template.format(pct=pct, top=top_label)

    return {
        "summary_fr": summary_fr,
        "top_features": top_features,
        "shap_base_value": round(score * 0.5, 4),
    }
