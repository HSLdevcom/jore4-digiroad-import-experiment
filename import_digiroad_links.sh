#!/usr/bin/env bash

EXECUTABLE_NAME=`basename "$0"`

# Either four database arguments expected or none at all.
if [[ "$#" -ne 0 && "$#" -ne 4 && "$#" -ne 5 ]]; then
    # Last parameter indicates whether Hasura DB should be updated.
    echo "Usage: ${EXECUTABLE_NAME} [<DB_HOST> <DB_PORT> <DB_NAME> <DB_USER> [true|false>]]"
    exit 1
fi

DB_HOST="${1:-localhost}"
DB_PORT="${2:-5432}"
DB_NAME="${3:-digiroad}"
DB_USER="${4:-digiroad}"
MIGRATE_TO_HASURA=${5:false}

PGDUMP_DIR="$(pwd)/workdir/pgdump"

# Stop on first error.
set -eu

# Find pg_dump file having date suffix for current day.
PGDUMP_FILE_PATTERN="digiroad_k_$(date "+%Y-%m-%d").pgdump"
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

if [[ ${MIGRATE_TO_HASURA} == "true" ]]; then
    echo "Migrating Digiroad links to Hasura/SQL schema."

    psql --set=AUTOCOMMIT=off -v ON_ERROR_STOP=1 -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" <<-EOSQL
        BEGIN;

        -- Matching is done by 'segm_id' field which is unique for each row (unlike 'link_id').
        UPDATE infrastructure_network.infrastructure_links AS dst
        SET infrastructure_link_geog = src.geog
        FROM ${SCHEMA_NAME}.dr_linkki_k AS src
        WHERE src.segm_id = dst.infrastructure_link_digiroad_segm_id;

        -- A 'road' row is required to exist in infrastructure_network.infrastructure_network_types tables.
        INSERT INTO infrastructure_network.infrastructure_links (infrastructure_link_geog, infrastructure_link_digiroad_id, infrastructure_link_digiroad_segm_id, infrastructure_network_type_id)
        SELECT src.geog,
            src.link_id,
            src.segm_id,
            (
                SELECT infrastructure_network_type_id
                FROM infrastructure_network.infrastructure_network_types
                WHERE infrastructure_network_type_name = 'road'
            )
        FROM ${SCHEMA_NAME}.dr_linkki_k src
        LEFT OUTER JOIN infrastructure_network.infrastructure_links dst ON src.segm_id = dst.infrastructure_link_digiroad_segm_id
        WHERE dst.infrastructure_link_digiroad_id IS NULL;

        COMMIT;
EOSQL
fi
