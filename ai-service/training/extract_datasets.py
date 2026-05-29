"""
Export ML datasets from MySQL (run inside Docker network or with DB env vars).
"""
from __future__ import annotations

import os
from datetime import date
from pathlib import Path


def main():
    try:
        import pandas as pd
        from sqlalchemy import create_engine
    except ImportError:
        print("pip install pandas sqlalchemy pymysql")
        return

    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "3306")
    user = os.getenv("DB_USER", "root")
    password = os.getenv("DB_PASSWORD", "admin")
    database = os.getenv("DB_NAME", "fs_hub_db")

    url = f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"
    engine = create_engine(url)

    out = Path("data/snapshots") / date.today().isoformat()
    out.mkdir(parents=True, exist_ok=True)

    queries = {
        "project_delay": "SELECT * FROM vw_ml_project_delay_features",
    }

    for name, sql in queries.items():
        try:
            df = pd.read_sql(sql, engine)
            path = out / f"{name}.parquet"
            df.to_parquet(path, index=False)
            print(f"[extract] {name}: {len(df)} rows -> {path}")
        except Exception as e:
            print(f"[extract] {name} failed: {e}")


if __name__ == "__main__":
    main()
