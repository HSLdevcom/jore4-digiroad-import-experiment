#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Start Docker container.
#
# The container is expected to exist and contain Digiroad schema with data
# populated from shapefiles.
docker start $DOCKER_CONTAINER_NAME

# Wait for PostgreSQL to start.
docker exec "${DOCKER_CONTAINER_NAME}" sh -c "$PG_WAIT_LOCAL"

# Create routing schema. pgRouting topology is created as well.
docker run --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${CWD}/sql:/tmp/sql ${DOCKER_IMAGE} \
  sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/routing/create_routing_schema.sql -v source_schema=${DB_IMPORT_SCHEMA_NAME} -v schema=${DB_ROUTING_SCHEMA_NAME} -v sql_dir=/tmp/sql"

DUMP_DIR="${WORK_DIR}/pgdump"
DUMP_FILE_BASENAME="digiroad_r_routing_$(date "+%Y-%m-%d")"
SQL_OUTPUT="${DUMP_FILE_BASENAME}.sql"
PGDUMP_OUTPUT="${DUMP_FILE_BASENAME}.pgdump"

mkdir -p "${DUMP_DIR}"

# Export the entire routing schema in SQL format for currently set-up production
# profile of map-matching backend where database migration scripts are bypassed.
# All the table definitions are created and data populated in one shot based on
# this dump.
docker run --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${DUMP_DIR}:/tmp/pgdump $DOCKER_IMAGE \
  sh -c "$PG_DUMP --clean --if-exists --no-owner -f /tmp/pgdump/${SQL_OUTPUT} --schema=${DB_ROUTING_SCHEMA_NAME}"

# Export the entire routing schema (with data) as a dump file in PostgreSQL's
# custom format. With custom format, the restoration of schema and/or table
# data items can be selectively filtered and applied by passing a toc list
# (table of contents) file as an argument to `pg_restore` command.
docker run --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${DUMP_DIR}:/tmp/pgdump $DOCKER_IMAGE \
  sh -c "$PG_DUMP --format=c --clean --no-owner -f /tmp/pgdump/${PGDUMP_OUTPUT} --schema=${DB_ROUTING_SCHEMA_NAME}"

# Dump a toc list file (for the generated pg_dump file) that lists the items
# contained in the dump file. The list can be edited by re-ordering or
# removing items that are not intended to be restored. That makes it possible
# to e.g. restore data only for selected database tables.
docker run --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${DUMP_DIR}:/tmp/pgdump $DOCKER_IMAGE \
  sh -c "pg_restore --list \"/tmp/pgdump/${PGDUMP_OUTPUT}\" --file=\"/tmp/pgdump/${PGDUMP_OUTPUT}.list\""

# Derive additional toc lists for restoring data (and only data) for selected
# tables. The additional tocs are created with current deployment scenarios of
# map-matching Docker image taken into account.
${CWD}/util/create_additional_pgdump_tocs.sh ${DUMP_DIR}/${PGDUMP_OUTPUT}

# Stop Docker container.
docker stop $DOCKER_CONTAINER_NAME
