"""FastAPI service exposing the Olist pipeline queries as JSON endpoints.

Two data sources, selected with the DATA_SOURCE environment variable:
  - "bigquery" (default): runs the SQL files live against BigQuery.
  - "snapshot": serves pre-computed JSON files from snapshots/ (no credentials needed).
"""
import json
import logging
import os
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from bigquery_client import run_query
from queries import QUERY_REGISTRY, available_queries, load_query

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parent.parent
SNAPSHOTS_DIR = BASE_DIR / "snapshots"

DATA_SOURCE = os.environ.get("DATA_SOURCE", "bigquery").strip().lower()
if DATA_SOURCE not in {"bigquery", "snapshot"}:
    raise RuntimeError(f"Invalid DATA_SOURCE '{DATA_SOURCE}' (use 'bigquery' or 'snapshot')")

app = FastAPI(
    title="Olist Pipeline API",
    description="Business queries on top of the Olist star schema (BigQuery + dbt).",
    version="1.2.0",
)

# Allow any origin for demo purposes (GET only). Restrict in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.get("/", include_in_schema=False)
def root() -> dict:
    """Return API info at the root."""
    return api_info()


@app.get("/api")
def api_info() -> dict:
    return {
        "service": "Olist Pipeline API",
        "version": "1.2.0",
        "data_source": DATA_SOURCE,
        "endpoints": ["/health", "/queries"] + [f"/{name}" for name in available_queries()],
    }


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "data_source": DATA_SOURCE}


@app.get("/queries")
def list_queries() -> dict:
    return {"available": available_queries()}


@lru_cache(maxsize=len(QUERY_REGISTRY))
def _read_snapshot(name: str) -> dict:
    path = SNAPSHOTS_DIR / f"{name}.json"
    if not path.exists():
        raise FileNotFoundError(
            f"Missing snapshot file: {path.name} (run scripts/export_snapshots.py)"
        )
    return json.loads(path.read_text(encoding="utf-8"))


def _execute(name: str) -> dict:
    log.info("Serving query '%s' from %s", name, DATA_SOURCE)
    try:
        if name not in QUERY_REGISTRY:
            raise KeyError(name)

        if DATA_SOURCE == "snapshot":
            snapshot = _read_snapshot(name)
            rows = snapshot["rows"]
            return {
                "query": name,
                "source": "snapshot",
                "generated_at": snapshot.get("generated_at"),
                "row_count": len(rows),
                "rows": rows,
            }

        rows = run_query(load_query(name))
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Unknown query: {name}")
    except FileNotFoundError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        log.exception("Query execution failed")
        raise HTTPException(status_code=500, detail=f"Query failed: {e}")

    return {"query": name, "source": "bigquery", "row_count": len(rows), "rows": rows}


@app.get("/category-cancellations")
def category_cancellations() -> dict:
    """Which product categories have the highest cancellation rates?"""
    return _execute("category-cancellations")


@app.get("/delivery-vs-satisfaction")
def delivery_vs_satisfaction() -> dict:
    """How does delivery delay impact customer satisfaction?"""
    return _execute("delivery-vs-satisfaction")


@app.get("/state-performance")
def state_performance() -> dict:
    """Which Brazilian states have the worst delivery performance?"""
    return _execute("state-performance")


@app.get("/top-categories-revenue")
def top_categories_revenue() -> dict:
    """Which product categories drive the most revenue?"""
    return _execute("top-categories-revenue")
