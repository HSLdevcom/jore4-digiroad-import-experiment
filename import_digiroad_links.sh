#!/usr/bin/env bash

EXECUTABLE_NAME=`basename "$0"`

# Either four database arguments expected or none at all.
if [[ "$#" -ne 0 && "$#" -ne 4 ]]; then
    echo "Usage: ${EXECUTABLE_NAME} [<DB_HOST> <DB_PORT> <DB_NAME> <DB_USER>]"
    exit 1
fi

DB_HOST="${1:-localhost}"
DB_PORT="${2:-5432}"
DB_NAME="${3:-digiroad}"
DB_USER="${4:-digiroad}"

PGDUMP_DIR="$(pwd)/workdir/pgdump"

# Stop on first error.
set -eu

# Find pg_dump file having date suffix for current day.
PGDUMP_FILE_PATTERN="dr_links_$(date "+%Y-%m-%d").pgdump"
PGDUMP_FILE=$(find ${PGDUMP_DIR} -iname "${PGDUMP_FILE_PATTERN}")

if [[ ! -f "${PGDUMP_FILE}" ]]; then
    echo "pg_dump file not found."
    exit 1
fi

SCHEMA_NAME="digiroad"

# Create schema into target database. Schema name must match with what is used in the pg_dump file.
psql -v ON_ERROR_STOP=1 -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -b -c "CREATE SCHEMA IF NOT EXISTS ${SCHEMA_NAME};"

echo "Restoring Digiroad links from ${PGDUMP_FILE}"

pg_restore -v -Fc -j8 -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
 --no-security-labels --no-owner --no-privileges --clean --if-exists "${PGDUMP_FILE}"
