# Olist Pipeline: dbt + BigQuery + FastAPI

An analytics pipeline for the Olist Brazilian e-commerce dataset. Raw CSV files are loaded into BigQuery, modelled with dbt into a star schema, and served through a FastAPI service and a dashboard that answer four business questions.

<!-- Uncomment after deploying and adding the files:
**Live demo:** https://YOUR-APP.onrender.com · **Video:** https://YOUR-VIDEO-URL

![Dashboard](docs/screenshot.png)
-->

## Problem

The Olist dataset ships as separate CSV files (orders, items, payments, reviews, customers, products, sellers). They are not ready for analysis: answering "how much do late deliveries hurt satisfaction?" needs joins, consistent definitions and tested transformations, and the answer has to reach people who do not write SQL.

## Solution

1. **Ingest**: `ingest/load_olist.py` loads the CSV files into a raw BigQuery dataset.
2. **Model**: dbt builds staging views, intermediate views and a star schema of tables.
3. **Query**: four business questions are written as SQL files in `analytics/queries/`.
4. **Serve**: a FastAPI service exposes each question as a JSON endpoint, and a single-page dashboard consumes them.
5. **Orchestrate**: `run_pipeline.sh` runs ingestion, `dbt run` and `dbt test` in order.

## Architecture

```
Olist CSV files (Kaggle)
        │  ingest/load_olist.py
        ▼
BigQuery  raw_olist
        │  dbt
        ▼
staging (views) ──► intermediate (views) ──► marts (star schema, tables)
                                                │
              ┌─────────────────────────────────┤
              ▼                                 ▼
   analytics/queries/*.sql             analytics/bi/*.sql
              │                                 │
   FastAPI (api/)                        scripts/export_bi_extracts.py
     DATA_SOURCE = bigquery | snapshot          │
              │                                 ▼
   frontend/index.html                      bi/*.csv
```

## Data model

| Table | Grain |
|---|---|
| `fct_orders` | one row per order (99,441 rows): status, delivery days and delay, payment value, review score, cancellation and lateness flags |
| `fct_order_items` | one row per order item (112,650 rows): product, seller, customer, price, freight, category, order-level flags |
| `dim_customers`, `dim_sellers`, `dim_products`, `dim_date` | one row per entity or day |

Layers are configured in `dbt_project/dbt_project.yml`: staging and intermediate are views, marts are tables.

## Business questions and endpoints

| Endpoint | Question |
|---|---|
| `GET /category-cancellations` | Which product categories have the highest cancellation rates? |
| `GET /delivery-vs-satisfaction` | How does delivery delay impact customer satisfaction? |
| `GET /state-performance` | Which Brazilian states have the worst delivery performance? |
| `GET /top-categories-revenue` | Which product categories drive the most revenue? |

Also available: `GET /` (dashboard), `GET /api` (service info), `GET /health`, `GET /queries` and interactive docs at `/docs`.

Definitions used by the API queries: cancellation rate = canceled orders / all orders, late-delivery rate = late orders / all orders. (The BI extracts in `bi/` use late orders / delivered orders, which is stated where they are used.)

## Two data sources

The API reads from one of two sources, selected with `DATA_SOURCE`:

| Value | Behaviour |
|---|---|
| `bigquery` (default) | runs the SQL files live against BigQuery |
| `snapshot` | serves pre-computed JSON from `snapshots/`, no credentials needed |

Snapshots exist because BigQuery sandbox tables expire (60 days by default here). The public demo runs in snapshot mode, so the service account key never leaves the developer's machine. Regenerate the snapshots with `python scripts/export_snapshots.py`.

## Stack

Python 3.14 · BigQuery · dbt Core · FastAPI · Uvicorn · vanilla HTML/CSS/JS frontend · Bash

## Running locally

Prerequisites: a Google Cloud project with BigQuery, a service account key with BigQuery permissions, and the [Olist dataset from Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) extracted into `data/`.

```bash
git clone https://github.com/juanquiterio/olist-pipeline.git
cd olist-pipeline
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dbt.txt -r ingest/requirements.txt -r api/requirements-live.txt
cp .env.example .env     # then fill in your values

./run_pipeline.sh                  # load CSVs, dbt run, dbt test
python scripts/export_snapshots.py
uvicorn main:app --app-dir api --port 8000
```

Open <http://localhost:8000>.

`GOOGLE_APPLICATION_CREDENTIALS` must be an **absolute path**: dbt runs from `dbt_project/`, so a relative path would not resolve.

Pipeline modes:

```bash
./run_pipeline.sh              # reload CSVs, then dbt run + dbt test
./run_pipeline.sh dbt-only     # dbt run + dbt test only
```

## BI extracts

`python scripts/export_bi_extracts.py` runs the SQL in `analytics/bi/` and writes two small aggregated CSV files to `bi/`: orders by month, state and delivery outcome, and items by month, state and category. All measures are additive, so any tool can compute correct rates as ratios of sums. The script aborts if the delay convention is not as expected and reconciles its totals against the source tables (99,441 orders and 112,650 items).

These files feed the [Olist Business Dashboard](https://github.com/juanquiterio/olist-bi-dashboard).

## Deployment (Render)

- **Build command:** `pip install -r api/requirements.txt`
- **Start command:** `uvicorn main:app --app-dir api --host 0.0.0.0 --port $PORT`
- **Environment variable:** `DATA_SOURCE=snapshot`
- **Python:** pinned by `.python-version`
- No credentials are configured on Render. `.env`, `secrets/` and `data/` are git-ignored.

## Testing

`dbt test` runs as the last step of `run_pipeline.sh`. The BI export reconciles its output against the warehouse on every run.

## Technical decisions

- **Layered dbt project.** Staging cleans and renames, intermediate joins and derives, marts expose a star schema. Marts are tables for query speed, earlier layers stay views.
- **SQL in files, project id as a placeholder.** Queries use `${MARTS}`, replaced at runtime from environment variables. The repository contains no project identifiers.
- **Snapshot mode.** Decouples the public demo from warehouse credentials and from table expiry.
- **Lazy BigQuery import.** The client library is only imported in live mode, which keeps the snapshot deployment small.
- **Fail early in the pipeline script.** `set -euo pipefail`, mode validation and explicit checks for the virtual environment and `.env`.
- **Additive measures in exports.** Never average averages.

## Challenges and learnings

- **Table expiry.** Reading the dataset configuration showed a 60-day default expiration on every table. That decision shaped the snapshot design.
- **Secrets hygiene.** A pre-commit style check (`git check-ignore`, dry-run `git add -n`, grep for secrets) confirmed that the key, `.env` and raw data are never tracked.
- **Leftovers from a previous project.** A search for the old project id found it hard-coded in the SQL files. Replacing it with a placeholder removed the leak and made the queries portable.
- **Reconciling exports.** Comparing exported totals with the source tables caught definition differences before they reached a dashboard (for example, payments include freight while item sales do not).

## License

Code: MIT, see [LICENSE](LICENSE). The Olist dataset has its own license: check it on Kaggle before reusing the data, and keep the attribution.
