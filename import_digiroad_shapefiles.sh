#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

SHP_URL="https://aineistot.vayla.fi/digiroad/latest/Maakuntajako_DIGIROAD_K_EUREF-FIN/UUSIMAA.zip"

DOWNLOAD_TARGET_DIR="${WORK_DIR}/zip"
DOWNLOAD_TARGET_FILE="${DOWNLOAD_TARGET_DIR}/UUSIMAA_K.zip"

# Load zip file containing Digiroad shapefiles if it does not exist.
if [[ ! -f "$DOWNLOAD_TARGET_FILE" ]]; then
    mkdir -p "$DOWNLOAD_TARGET_DIR"
    curl -Lo $DOWNLOAD_TARGET_FILE $SHP_URL
fi

SHP_AREAS="ITA-UUSIMAA UUSIMAA_1 UUSIMAA_2"
SHP_FILE_DIR="${WORK_DIR}/shp"

LINK_BASENAME="DR_LINKKI_K"
LINK_FILENAME="${LINK_BASENAME}.shp"

for SHP_AREA in $SHP_AREAS
do
    if [[ ! -f "${SHP_FILE_DIR}/${SHP_AREA}/${LINK_FILENAME}" ]]; then
        mkdir -p "$SHP_FILE_DIR/${SHP_AREA}"
        # Extract shapefile.
        unzip -u $DOWNLOAD_TARGET_FILE ${SHP_AREA}/${LINK_BASENAME}.* -d $SHP_FILE_DIR
    fi
done

# Remove possibly running/existing Docker container.
docker kill $DOCKER_CONTAINER &> /dev/null || true
docker rm -v $DOCKER_CONTAINER &> /dev/null || true

# Create and start new Docker container.
docker run --name $DOCKER_CONTAINER -e POSTGRES_HOST_AUTH_METHOD=trust -d $DOCKER_IMAGE

# Wait for PostgreSQL to start.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres $DOCKER_IMAGE sh -c "$PG_WAIT"

# Create digiroad schema into database.
docker exec "${DOCKER_CONTAINER}" sh -c "$PSQL -nt -c \"CREATE SCHEMA ${DB_SCHEMA_NAME};\""

TABLE_REF="${DB_SCHEMA_NAME}.dr_linkki_k"
SHP2PGSQL="shp2pgsql -D -i -s 3067 -S -N abort -W $SHP_ENCODING"

# Only creates a table based on one shapefile. Relies on `SHP_AREA` variable that is declared previously.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE \
  sh -c "$SHP2PGSQL -p /tmp/shp/${SHP_AREA}/${LINK_FILENAME} $TABLE_REF | $PSQL -v ON_ERROR_STOP=1 -q"

# Import links from multiple shapefiles into one database table.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE \
  sh -c "for SHP_AREA in ${SHP_AREAS}; do $SHP2PGSQL -a /tmp/shp/\${SHP_AREA}/${LINK_FILENAME} $TABLE_REF | $PSQL -v ON_ERROR_STOP=1; done"

# Process road geometries and filtering properties in database.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres -v ${CWD}/sql:/tmp/sql \
  ${DOCKER_IMAGE} sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_linkki_k.sql -v schema=${DB_SCHEMA_NAME}"

# Stop Docker container.
docker stop $DOCKER_CONTAINER
