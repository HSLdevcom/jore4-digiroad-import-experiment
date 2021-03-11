#!/usr/bin/env bash

SHP_URL="https://aineistot.vayla.fi/digiroad/latest/Maakuntajako_DIGIROAD_R_EUREF-FIN/UUSIMAA.zip"

CWD=$(pwd)
WORK_DIR="${CWD}/workdir"

# Stop on first error.
set -eu

DOWNLOAD_TARGET_FILE="${WORK_DIR}/zip/UUSIMAA_R.zip"

if [[ ! -f "$DOWNLOAD_TARGET_FILE" ]]; then
    echo "Loading Digiroad shapefiles for Uusimaa..."
    curl -Lo $DOWNLOAD_TARGET_FILE $SHP_URL
fi

SHP_FILE_DIR="${WORK_DIR}/shp"
SHP_NAME="UUSIMAA_2/DR_LINKKI"

if [[ ! -f "${SHP_FILE_DIR}/${SHP_NAME}.shp" ]]; then
    echo "Extracting UUSIMAA2 shapefile for road links..."
    unzip -u $DOWNLOAD_TARGET_FILE $SHP_NAME.* -d $SHP_FILE_DIR
fi

DOCKER_IMAGE_NAME="jore4/postgis-digiroad"
DOCKER_CONTAINER_NAME="jore4-postgis-digiroad"

# Remove possibly running/existing Docker container.
docker kill $DOCKER_CONTAINER_NAME &> /dev/null || true
docker rm $DOCKER_CONTAINER_NAME &> /dev/null || true

# Start Docker container.
docker run --name $DOCKER_CONTAINER_NAME -e POSTGRES_HOST_AUTH_METHOD=trust -d $DOCKER_IMAGE_NAME

# Docker commands
DB_NAME="digiroad"
PSQL='exec psql -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U postgres -d "$DB_NAME" --no-password'
PG_DUMP='exec pg_dump -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U postgres -d "$DB_NAME" --no-password'
PG_WAIT='exec /wait-pg.sh "$DB_NAME" "$POSTGRES_PORT_5432_TCP_ADDR" "$POSTGRES_PORT_5432_TCP_PORT"'

# Wait for PostgreSQL to start.
docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres $DOCKER_IMAGE_NAME sh -c "$PG_WAIT"

SHP_ENCODING="UTF-8"
SCHEMA_NAME="digiroad_import"
TABLE_INPUT="${SCHEMA_NAME}.dr_links_in"
TABLE_OUTPUT="${SCHEMA_NAME}.dr_links"
PGDUMP_OUTPUT="dr_links_$(date "+%Y-%m-%d").pgdump"

docker exec "${DOCKER_CONTAINER_NAME}" sh -c "$PSQL -nt -c 'CREATE SCHEMA ${SCHEMA_NAME};'"

echo "Loading shapefile into PostGIS database through pg_dump transformation..."

docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE_NAME \
  sh -c "shp2pgsql -c -N abort -D -i -s 3067 -W $SHP_ENCODING -D /tmp/shp/${SHP_NAME}.shp $TABLE_INPUT | $PSQL -v ON_ERROR_STOP=1 -q"

echo "Processing road geometries and filtering properties in PostGIS database..."

docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${CWD}/sql:/tmp/sql ${DOCKER_IMAGE_NAME} \
  sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_links.sql"

echo "Number of processed Digiroad links:"
docker exec "${DOCKER_CONTAINER_NAME}" sh -c "$PSQL -nt -c 'SELECT COUNT(*) FROM ${TABLE_OUTPUT};'"

echo "Exporting pg_dump file as output..."

docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${WORK_DIR}/pgdump/:/tmp/pgdump $DOCKER_IMAGE_NAME \
  sh -c "$PG_DUMP -Fc --clean --table $TABLE_OUTPUT -f /tmp/pgdump/${PGDUMP_OUTPUT}"

echo "Stopping Docker container..."

docker stop $DOCKER_CONTAINER_NAME

echo "Done."
