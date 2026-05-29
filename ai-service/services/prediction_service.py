"""Backward-compatible shim — delegates to HeuristicEngine."""

from app.ml.heuristic import HeuristicEngine as PredictionService

__all__ = ["PredictionService"]
