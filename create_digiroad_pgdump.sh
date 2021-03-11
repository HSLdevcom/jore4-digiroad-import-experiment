#!/usr/bin/env bash

SHP_URL="https://aineistot.vayla.fi/digiroad/latest/Maakuntajako_DIGIROAD_K_EUREF-FIN/UUSIMAA.zip"

CWD=$(pwd)
WORK_DIR="${CWD}/workdir"

# Stop on first error.
set -euo pipefail

DOWNLOAD_TARGET_DIR="${WORK_DIR}/zip"
DOWNLOAD_TARGET_FILE="${DOWNLOAD_TARGET_DIR}/UUSIMAA.zip"

if [[ ! -f "$DOWNLOAD_TARGET_FILE" ]]; then
    mkdir -p "$DOWNLOAD_TARGET_DIR"
    echo "Loading Digiroad shapefiles for Uusimaa..."
    curl -Lo $DOWNLOAD_TARGET_FILE $SHP_URL
fi

SHP_FILE_DIR="${WORK_DIR}/shp"
SHP_NAMES="ITA-UUSIMAA UUSIMAA_1 UUSIMAA_2"

LINK_BASENAME="DR_LINKKI_K"
LINK_FILENAME="${LINK_BASENAME}.shp"

for SHP_NAME in $SHP_NAMES
do
    if [[ ! -f "${SHP_FILE_DIR}/${SHP_NAME}/${LINK_FILENAME}" ]]; then
        mkdir -p "$SHP_FILE_DIR/${SHP_NAME}"
        echo "Extracting $SHP_NAME shapefile for road links..."
        unzip -u $DOWNLOAD_TARGET_FILE ${SHP_NAME}/${LINK_BASENAME}.* -d $SHP_FILE_DIR
    fi
done

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

SCHEMA_NAME="digiroad"
TABLE_INPUT="${SCHEMA_NAME}.dr_linkki_in"
TABLE_OUTPUT="${SCHEMA_NAME}.dr_linkki"
PGDUMP_OUTPUT="dr_links_$(date "+%Y-%m-%d").pgdump"
SHP2PGSQL="shp2pgsql -D -i -s 3067 -N abort -W UTF-8"

docker exec "${DOCKER_CONTAINER_NAME}" sh -c "$PSQL -nt -c 'CREATE SCHEMA ${SCHEMA_NAME};'"

echo "Creating PostGIS table..."

# Only creates a table based on one shapefile. Relies on `SHP_NAME` variable that is declared previously.
docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE_NAME \
  sh -c "$SHP2PGSQL -p /tmp/shp/${SHP_NAME}/${LINK_FILENAME} $TABLE_INPUT | $PSQL -v ON_ERROR_STOP=1 -q"

echo "Loading shapefiles into PostGIS database through pg_dump transformation..."

# Import links from multiple shapefiles into one database table.
docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE_NAME \
  sh -c "for SHP_NAME in ${SHP_NAMES}; do $SHP2PGSQL -a /tmp/shp/\${SHP_NAME}/${LINK_FILENAME} $TABLE_INPUT | $PSQL -v ON_ERROR_STOP=1; done"

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
