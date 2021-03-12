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

SCHEMA_NAME="digiroad_import"

# Create `import` schema because tables in pg_dump file reside in that schema.
psql -v ON_ERROR_STOP=1 -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -b -c "CREATE SCHEMA IF NOT EXISTS ${SCHEMA_NAME};"

echo "Restoring Digiroad links from ${PGDUMP_FILE}"

pg_restore -v -Fc -j8 -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
 --no-security-labels --no-owner --no-privileges --clean --if-exists "${PGDUMP_FILE}"

echo "Migrating Digiroad links to Hasura/SQL schema."

psql --set=AUTOCOMMIT=off -v ON_ERROR_STOP=1 -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" <<-EOSQL
    BEGIN;

    UPDATE infrastructure_network.infrastructure_links AS dst
    SET infrastructure_link_geog = src.geog
    FROM ${SCHEMA_NAME}.dr_links AS src
    WHERE src.digiroad_id = dst.infrastructure_link_digiroad_id;

    -- A 'road' row is required to exist in infrastructure_network.infrastructure_network_types tables.
    INSERT INTO infrastructure_network.infrastructure_links (infrastructure_link_geog, infrastructure_link_digiroad_id, infrastructure_network_type_id)
    SELECT src.geog,
        src.digiroad_id,
        (
            SELECT infrastructure_network_type_id
            FROM infrastructure_network.infrastructure_network_types
            WHERE infrastructure_network_type_name = 'road'
        )
    FROM ${SCHEMA_NAME}.dr_links src
    LEFT OUTER JOIN infrastructure_network.infrastructure_links dst ON src.digiroad_id = dst.infrastructure_link_digiroad_id
    WHERE dst.infrastructure_link_digiroad_id IS NULL;

    COMMIT;
EOSQL
