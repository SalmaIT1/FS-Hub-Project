# FS-Hub AI Service

Python FastAPI microservice for ML inference and decision support.

## Run locally

```bash
cd ai-service
pip install -r requirements.txt
set AI_ALLOW_DEV_KEY=true
set AI_API_KEY=dev-ai-key-change-me
uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

## Docker

Started via root `docker-compose.yml` as service `ai-service`.

## API

- `GET /health`
- `GET /v1/models/status` (requires `X-API-Key`)
- `POST /v1/predict/project-delay`
- Legacy: `POST /ai/predict-delay` (Shelf compatibility)

## Training

```bash
pip install -r requirements-train.txt
python training/extract_datasets.py
python training/train_project_delay.py --snapshot data/snapshots/YYYY-MM-DD/project_delay.parquet
```

Promote model: copy artifact to `models/project_delay/current/model.joblib`.
