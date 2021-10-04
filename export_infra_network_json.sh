#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker start $DOCKER_CONTAINER

# Wait for PostgreSQL to start.
docker exec "${DOCKER_CONTAINER}" sh -c "$PG_WAIT_LOCAL"

PGDUMP_OUTPUT="infra_network_digiroad_r_$(date "+%Y-%m-%d").json"
mkdir -p ${WORK_DIR}/output

# Export pg_dump file.
docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${CWD}/sql:/tmp/sql -v ${CWD}/workdir/output:/tmp/output \
  ${DOCKER_IMAGE} sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/select_infra_links.sql -o /tmp/output/${PGDUMP_OUTPUT} --tuples-only --no-align -v schema=${DB_IMPORT_SCHEMA_NAME}"

# Stop Docker container.
docker stop $DOCKER_CONTAINER
