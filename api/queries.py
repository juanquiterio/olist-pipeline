"""Loads SQL files from analytics/queries/ at runtime."""
import os
from functools import lru_cache
from pathlib import Path

QUERIES_DIR = Path(__file__).resolve().parent.parent / "analytics" / "queries"

QUERY_REGISTRY = {
    "category-cancellations":    "01_category_cancellations.sql",
    "delivery-vs-satisfaction":  "02_delivery_vs_satisfaction.sql",
    "state-performance":         "03_state_performance.sql",
    "top-categories-revenue":    "04_top_categories_revenue.sql",
}

MARTS_PLACEHOLDER = "${MARTS}"


def marts_dataset_path() -> str:
    """Return '<project>.<analytics dataset>_marts' built from the environment."""
    project = os.environ.get("GCP_PROJECT_ID")
    if not project:
        raise RuntimeError("GCP_PROJECT_ID is not set")
    analytics = os.environ.get("GCP_DATASET_ANALYTICS", "analytics_olist")
    return f"{project}.{analytics}_marts"


@lru_cache(maxsize=None)
def load_query(name: str) -> str:
    if name not in QUERY_REGISTRY:
        raise KeyError(f"Unknown query: {name}")

    filepath = QUERIES_DIR / QUERY_REGISTRY[name]
    if not filepath.exists():
        raise FileNotFoundError(f"Missing query file: {filepath}")

    sql = filepath.read_text(encoding="utf-8")
    return sql.replace(MARTS_PLACEHOLDER, marts_dataset_path())


def available_queries() -> list[str]:
    return list(QUERY_REGISTRY.keys())
