"""Export every API query to snapshots/<name>.json so the API can run without BigQuery.

Run locally (needs .env and BigQuery access):
    python scripts/export_snapshots.py
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "api"))

from bigquery_client import run_query  # noqa: E402
from queries import QUERY_REGISTRY, load_query  # noqa: E402

SNAPSHOTS_DIR = ROOT / "snapshots"


def main() -> None:
    SNAPSHOTS_DIR.mkdir(exist_ok=True)
    generated_at = datetime.now(timezone.utc).isoformat(timespec="seconds")

    for name in QUERY_REGISTRY:
        rows = run_query(load_query(name))
        payload = {"generated_at": generated_at, "rows": rows}
        path = SNAPSHOTS_DIR / f"{name}.json"
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"{name}: {len(rows)} rows -> {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
