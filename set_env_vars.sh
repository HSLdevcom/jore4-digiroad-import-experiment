#!/usr/bin/env bash

# Set correct working directory.
export CWD="$(cd "$(dirname "$0")"; pwd -P)"
export WORK_DIR="${CWD}/workdir"

export SHP_ENCODING="UTF-8"

export DOCKER_IMAGE="jore4/postgis-digiroad"
export DOCKER_CONTAINER="jore4-postgis-digiroad"

# Database details
export DB_NAME="digiroad"
export DB_IMPORT_SCHEMA_NAME="digiroad"
export DB_MBTILES_SCHEMA_NAME="mbtiles"
export DB_ROUTING_SCHEMA_NAME="routing"

# Commands to run inside Docker container.
export PSQL='exec psql -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U digiroad -d digiroad --no-password'
export PG_WAIT='exec /wait-pg.sh "$DB_NAME" "$POSTGRES_PORT_5432_TCP_ADDR" "$POSTGRES_PORT_5432_TCP_PORT"'
export PG_WAIT_LOCAL='exec /wait-pg.sh "$DB_NAME" localhost "$POSTGRES_PORT_5432_TCP_PORT"'
export PG_DUMP='exec pg_dump -h ${POSTGRES_PORT_5432_TCP_ADDR} -p ${POSTGRES_PORT_5432_TCP_PORT} -d digiroad -U digiroad --no-password'
