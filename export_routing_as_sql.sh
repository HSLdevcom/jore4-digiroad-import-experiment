#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker start $DOCKER_CONTAINER

# Wait for PostgreSQL to start.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres $DOCKER_IMAGE sh -c "$PG_WAIT"

# Export sql file.
SQL_OUTPUT="digiroad_r_routing_$(date "+%Y-%m-%d").sql"
mkdir -p ${WORK_DIR}/output
docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${WORK_DIR}/output/:/tmp/output $DOCKER_IMAGE \
  sh -c "$PG_DUMP --no-owner -f /tmp/output/${SQL_OUTPUT} --schema=${DB_ROUTING_SCHEMA_NAME}"

# Stop Docker container.
docker stop $DOCKER_CONTAINER
