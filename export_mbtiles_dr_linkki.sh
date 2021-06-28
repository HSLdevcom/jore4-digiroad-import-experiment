#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

DB_TABLE_NAME="dr_linkki"

MBTILES_MAX_ZOOM_LEVEL=16
MBTILES_LAYER_NAME=$DB_TABLE_NAME
MBTILES_DESCRIPTION="Digiroad road links"

MBTILES_OUTPUT_DIR="${WORK_DIR}/mbtiles"
SHP_OUTPUT_DIR="${MBTILES_OUTPUT_DIR}/shp_input"
GEOJSON_OUTPUT_DIR="${MBTILES_OUTPUT_DIR}/geojson_input"

mkdir -p "$SHP_OUTPUT_DIR"
mkdir -p "$GEOJSON_OUTPUT_DIR"

OUTPUT_FILE_BASENAME="${DB_TABLE_NAME}_$(date "+%Y-%m-%d")"

SHP_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.shp"
GEOJSON_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.geojson"
MBTILES_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.mbtiles"

# Start Docker container. The container is expected to exist and contain required database table to be exported.
docker start $DOCKER_CONTAINER

# Wait for PostgreSQL to start.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres $DOCKER_IMAGE sh -c "$PG_WAIT"

PGSQL2SHP='pgsql2shp -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -u digiroad'

# Export pg_dump file from database.
time docker run -it --rm --link "${DOCKER_CONTAINER}":postgres -v ${SHP_OUTPUT_DIR}/:/tmp/shp $DOCKER_IMAGE \
  sh -c "$PGSQL2SHP -f /tmp/shp/${SHP_OUTPUT_FILE} digiroad ${DB_MBTILES_SCHEMA_NAME}.${DB_TABLE_NAME}"

# Convert from Shapefile to GeoJSON.

rm -f ${GEOJSON_OUTPUT_DIR}/$GEOJSON_OUTPUT_FILE || true
time docker run -it --rm -v ${SHP_OUTPUT_DIR}/:/tmp/shp -v ${GEOJSON_OUTPUT_DIR}:/tmp/geojson ${DOCKER_IMAGE} \
  sh -c "ogr2ogr --config SHAPE_ENCODING $SHP_ENCODING -f GeoJSON -lco COORDINATE_PRECISION=7 /tmp/geojson/$GEOJSON_OUTPUT_FILE /tmp/shp/$SHP_OUTPUT_FILE"

# Convert from GeoJSON to MBTiles.

rm -f "${MBTILES_OUTPUT_DIR}/${MBTILES_OUTPUT_FILE}" || true
rm -f "${MBTILES_OUTPUT_DIR}/${MBTILES_OUTPUT_FILE}-journal" || true
docker run -it --rm -v ${MBTILES_OUTPUT_DIR}/:/tmp/mbtiles -v ${GEOJSON_OUTPUT_DIR}:/tmp/geojson ${DOCKER_IMAGE} \
  sh -c "tippecanoe /tmp/geojson/$GEOJSON_OUTPUT_FILE -o /tmp/$MBTILES_OUTPUT_FILE -z$MBTILES_MAX_ZOOM_LEVEL -X -l $MBTILES_LAYER_NAME -n \"$MBTILES_DESCRIPTION\" -f; mv /tmp/$MBTILES_OUTPUT_FILE /tmp/mbtiles/$MBTILES_OUTPUT_FILE"

# Stop Docker container.
docker stop $DOCKER_CONTAINER
