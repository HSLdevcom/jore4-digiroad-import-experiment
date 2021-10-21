#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker start $DOCKER_CONTAINER

# Wait for PostgreSQL to start.
docker exec "${DOCKER_CONTAINER}" sh -c "$PG_WAIT_LOCAL"

# Export CSV file to output directory.
OUTPUT_FILENAME="infra_network_digiroad.csv"
OUTPUT_FOLDER="${WORK_DIR}/csv"
mkdir -p "${OUTPUT_FOLDER}"
docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${CWD}/sql:/tmp/sql -v ${OUTPUT_FOLDER}:/tmp/csv ${DOCKER_IMAGE} \
  sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/select_infra_links_as_csv.sql -v schema=${DB_IMPORT_SCHEMA_NAME} -o /tmp/csv/${OUTPUT_FILENAME}"

# Stop Docker container.
docker stop $DOCKER_CONTAINER
