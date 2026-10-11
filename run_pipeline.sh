#!/usr/bin/env bash
# run_pipeline.sh — Orchestrates CSV load + dbt run + dbt test.
# Usage:
#   ./run_pipeline.sh            -> reload CSVs into BigQuery, then run dbt
#   ./run_pipeline.sh dbt-only   -> dbt run + dbt test only (skip CSV reload)

set -euo pipefail

MODE="${1:-full}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_ACTIVATE="$PROJECT_DIR/.venv/bin/activate"
ENV_FILE="$PROJECT_DIR/.env"
DBT_DIR="$PROJECT_DIR/dbt_project"

if [[ "$MODE" != "full" && "$MODE" != "dbt-only" ]]; then
    echo "ERROR: unknown mode '$MODE' (use 'full' or 'dbt-only')"
    exit 1
fi

if [[ ! -f "$VENV_ACTIVATE" ]]; then
    echo "ERROR: virtual environment not found at $VENV_ACTIVATE"
    exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

echo "==> Activating virtual environment"
source "$VENV_ACTIVATE"

echo "==> Loading environment variables"
set -a
source "$ENV_FILE"
set +a

if [[ "$MODE" == "full" ]]; then
    echo "==> Loading CSVs into BigQuery"
    python "$PROJECT_DIR/ingest/load_olist.py"
fi

echo "==> dbt deps"
cd "$DBT_DIR"
export DBT_PROFILES_DIR="$DBT_DIR"
dbt deps

echo "==> dbt run"
dbt run

echo "==> dbt test"
dbt test

echo "==> Pipeline completed"
