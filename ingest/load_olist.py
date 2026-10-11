"""Load Olist CSV files from data/ into BigQuery raw dataset."""
import os
import logging
from pathlib import Path

from google.cloud import bigquery
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"

# Map: BigQuery table name -> CSV filename
CSV_TABLES = {
    "customers":            "olist_customers_dataset.csv",
    "orders":               "olist_orders_dataset.csv",
    "order_items":          "olist_order_items_dataset.csv",
    "order_payments":       "olist_order_payments_dataset.csv",
    "order_reviews":        "olist_order_reviews_dataset.csv",
    "products":             "olist_products_dataset.csv",
    "sellers":              "olist_sellers_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}

# Explicit schemas for tables with problematic headers (BOM, malformed names)
EXPLICIT_SCHEMAS = {
    "category_translation": [
        bigquery.SchemaField("product_category_name", "STRING"),
        bigquery.SchemaField("product_category_name_english", "STRING"),
    ],
}


def load_csv_to_bigquery(client: bigquery.Client, table_name: str, csv_path: Path) -> None:
    project = os.environ["GCP_PROJECT_ID"]
    dataset = os.environ["GCP_DATASET_RAW"]
    table_id = f"{project}.{dataset}.{table_name}"

    config_kwargs = {
        "source_format": bigquery.SourceFormat.CSV,
        "skip_leading_rows": 1,
        "write_disposition": bigquery.WriteDisposition.WRITE_TRUNCATE,
        "encoding": "UTF-8",
        "allow_quoted_newlines": True,
        "max_bad_records": 1000,
    }

    if table_name in EXPLICIT_SCHEMAS:
        config_kwargs["schema"] = EXPLICIT_SCHEMAS[table_name]
    else:
        config_kwargs["autodetect"] = True

    job_config = bigquery.LoadJobConfig(**config_kwargs)

    log.info("Loading %s -> %s", csv_path.name, table_id)

    with open(csv_path, "rb") as source_file:
        job = client.load_table_from_file(source_file, table_id, job_config=job_config)
        job.result()

    table = client.get_table(table_id)
    log.info("  -> %d rows", table.num_rows)


def main():
    project = os.environ["GCP_PROJECT_ID"]
    client = bigquery.Client(project=project)

    for table_name, filename in CSV_TABLES.items():
        csv_path = DATA_DIR / filename
        if not csv_path.exists():
            log.warning("Skipping %s (not found at %s)", table_name, csv_path)
            continue
        try:
            load_csv_to_bigquery(client, table_name, csv_path)
        except Exception as e:
            log.error("Failed to load %s: %s", table_name, e)

    log.info("Done.")


if __name__ == "__main__":
    main()
