"""
Train project delay classifier when sufficient labeled data exists.
Usage: python -m training.train_project_delay --snapshot data/snapshots/latest/project_delay.parquet
"""
from __future__ import annotations

import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Train FS-Hub project delay model")
    parser.add_argument("--snapshot", type=str, default="", help="Parquet/CSV snapshot path")
    parser.add_argument("--min-rows", type=int, default=200)
    args = parser.parse_args()

    if not args.snapshot or not Path(args.snapshot).exists():
        print(
            "[train] No snapshot found. Export from vw_ml_project_delay_features first. "
            "Using heuristic-v1 in production until data is ready."
        )
        return

    try:
        import pandas as pd
        from sklearn.ensemble import RandomForestClassifier
        from sklearn.metrics import roc_auc_score, f1_score
        from sklearn.model_selection import train_test_split
        import joblib
    except ImportError as e:
        print(f"[train] Missing dependency: {e}. pip install -r requirements-train.txt")
        return

    df = pd.read_parquet(args.snapshot) if args.snapshot.endswith(".parquet") else pd.read_csv(args.snapshot)
    if len(df) < args.min_rows:
        print(f"[train] Only {len(df)} rows — need {args.min_rows}. Skipping.")
        return

    feature_cols = [
        "total_tasks",
        "completed_tasks",
        "delayed_tasks",
        "days_to_deadline",
        "team_size",
        "client_outstanding",
        "sprint_count",
    ]
    for col in feature_cols:
        if col not in df.columns:
            df[col] = 0

    X = df[feature_cols].fillna(0)
    y = df["is_delayed_label"].astype(int)

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

    model = RandomForestClassifier(n_estimators=100, max_depth=8, random_state=42, class_weight="balanced")
    model.fit(X_train, y_train)

    proba = model.predict_proba(X_test)[:, 1]
    preds = model.predict(X_test)
    auc = roc_auc_score(y_test, proba)
    f1 = f1_score(y_test, preds)

    print(f"[train] ROC-AUC={auc:.4f} F1={f1:.4f}")

    out_dir = Path("models/project_delay/v1.0.0")
    out_dir.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": model, "feature_names": feature_cols}, out_dir / "model.joblib")
    (out_dir / "version.txt").write_text("v1.0.0")
    print(f"[train] Saved to {out_dir}")


if __name__ == "__main__":
    main()
