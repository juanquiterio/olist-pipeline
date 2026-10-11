"""BigQuery client wrapper for the Olist pipeline API (live mode only)."""
import os
from decimal import Decimal
from functools import lru_cache
from typing import TYPE_CHECKING, Any

from dotenv import load_dotenv

if TYPE_CHECKING:
    from google.cloud import bigquery

load_dotenv()


@lru_cache(maxsize=1)
def get_client() -> "bigquery.Client":
    """Return a cached BigQuery client (imported lazily to save memory)."""
    from google.cloud import bigquery

    project = os.environ["GCP_PROJECT_ID"]
    return bigquery.Client(project=project)


def _serialize(value: Any) -> Any:
    """Convert BigQuery types to JSON-friendly Python types."""
    if isinstance(value, Decimal):
        return float(value)
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return value


def run_query(sql: str) -> list[dict[str, Any]]:
    """Execute a SQL query and return rows as a list of dicts."""
    client = get_client()
    job = client.query(sql)
    result = job.result()

    rows: list[dict[str, Any]] = []
    for row in result:
        record = {key: _serialize(value) for key, value in row.items()}
        rows.append(record)
    return rows
