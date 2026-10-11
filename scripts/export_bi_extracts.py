"""Export the two aggregated tables that feed the BI dashboard.

Reads the SQL in analytics/bi/, runs it against the BigQuery marts and writes
bi/<name>.csv. Run from the project root (needs .env and BigQuery access):

    python scripts/export_bi_extracts.py
"""
import csv
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from google.cloud import bigquery

ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = ROOT / "analytics" / "bi"
OUT_DIR = ROOT / "bi"
MARTS_PLACEHOLDER = "${MARTS}"

# export name -> (source table, additive column used to reconcile row counts)
EXPORTS = {
    "orders_by_month_state_delay": ("fct_orders", "orders"),
    "items_by_month_state_category": ("fct_order_items", "items"),
}


def configure() -> tuple[bigquery.Client, str]:
    load_dotenv(ROOT / ".env")
    credentials = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if credentials and not Path(credentials).is_absolute():
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str((ROOT / credentials).resolve())

    project = os.environ["GCP_PROJECT_ID"]
    marts = f"{project}.{os.environ['GCP_DATASET_ANALYTICS']}_marts"
    return bigquery.Client(project=project), marts


def check_lateness_convention(client: bigquery.Client, marts: str) -> None:
    """Abort if delivery_delay_days does not mean 'days late' (positive = late)."""
    sql = f"""
        SELECT
            AVG(IF(is_late = 1, delivery_delay_days, NULL))                      AS avg_when_late,
            AVG(IF(is_late = 0 AND is_delivered = 1, delivery_delay_days, NULL)) AS avg_when_on_time
        FROM `{marts}.fct_orders`
    """
    row = next(iter(client.query(sql).result()))
    print(f"Lateness check: avg delay when late = {row.avg_when_late:.2f} days, "
          f"when on time = {row.avg_when_on_time:.2f} days")
    if row.avg_when_late is None or row.avg_when_late <= 0 or row.avg_when_late <= row.avg_when_on_time:
        raise SystemExit("Unexpected delay convention: delivery_delay_days is not 'positive = late'.")


def load_sql(name: str, marts: str) -> str:
    sql = (SQL_DIR / f"{name}.sql").read_text(encoding="utf-8")
    return sql.replace(MARTS_PLACEHOLDER, marts)


def export(client: bigquery.Client, name: str, marts: str) -> tuple[Path, int]:
    result = client.query(load_sql(name, marts)).result()
    header = [field.name for field in result.schema]

    OUT_DIR.mkdir(exist_ok=True)
    path = OUT_DIR / f"{name}.csv"
    rows = 0
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        for row in result:
            writer.writerow(row.values())
            rows += 1
    return path, rows


def reconcile(client: bigquery.Client, marts: str, table: str, measure: str, path: Path) -> bool:
    """The CSV totals must match a direct count on the source table."""
    sql = f"""
        SELECT COUNT(*) AS n
        FROM `{marts}.{table}`
        WHERE customer_state IS NOT NULL AND purchase_date_key IS NOT NULL
    """
    expected = next(iter(client.query(sql).result())).n
    with path.open(encoding="utf-8", newline="") as handle:
        actual = sum(int(record[measure]) for record in csv.DictReader(handle))

    ok = actual == expected
    print(f"  reconcile {measure}: csv={actual:,} source={expected:,} -> {'OK' if ok else 'MISMATCH'}")
    return ok


def main() -> None:
    client, marts = configure()
    check_lateness_convention(client, marts)

    all_ok = True
    for name, (table, measure) in EXPORTS.items():
        path, rows = export(client, name, marts)
        size_kb = path.stat().st_size / 1024
        print(f"{name}: {rows:,} rows, {size_kb:,.0f} KB -> {path.relative_to(ROOT)}")
        all_ok &= reconcile(client, marts, table, measure, path)

    if not all_ok:
        sys.exit(1)
    print("Done.")


if __name__ == "__main__":
    main()
