#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

SHP_URL="https://aineistot.vayla.fi/digiroad/latest/Maakuntajako_DIGIROAD_K_EUREF-FIN/UUSIMAA.zip"

CWD=$(pwd)
WORK_DIR="${CWD}/workdir"

DOWNLOAD_TARGET_DIR="${WORK_DIR}/zip"
DOWNLOAD_TARGET_FILE="${DOWNLOAD_TARGET_DIR}/UUSIMAA_K.zip"

# Load zip file containing Digiroad shapefiles if it does not exist.
if [[ ! -f "$DOWNLOAD_TARGET_FILE" ]]; then
    mkdir -p "$DOWNLOAD_TARGET_DIR"
    curl -Lo $DOWNLOAD_TARGET_FILE $SHP_URL
fi

SHP_FILE_DIR="${WORK_DIR}/shp"
SHP_AREAS="ITA-UUSIMAA UUSIMAA_1 UUSIMAA_2"

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

DOCKER_IMAGE_NAME="jore4/postgis-digiroad"
DOCKER_CONTAINER_NAME="jore4-postgis-digiroad"

# Remove possibly running/existing Docker container.
docker kill $DOCKER_CONTAINER_NAME &> /dev/null || true
docker rm -v $DOCKER_CONTAINER_NAME &> /dev/null || true

# Create and start new Docker container.
docker run --name $DOCKER_CONTAINER_NAME -e POSTGRES_HOST_AUTH_METHOD=trust -d $DOCKER_IMAGE_NAME

DB_NAME="digiroad"

# Commands to run inside Docker container.
PSQL='exec psql -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U digiroad -d digiroad --no-password'
PG_DUMP='exec pg_dump -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U digiroad -d digiroad --no-password'
PG_WAIT='exec /wait-pg.sh "$DB_NAME" "$POSTGRES_PORT_5432_TCP_ADDR" "$POSTGRES_PORT_5432_TCP_PORT"'

# Wait for PostgreSQL to start.
docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres $DOCKER_IMAGE_NAME sh -c "$PG_WAIT"

SCHEMA_NAME="digiroad"
TABLE_REF="${SCHEMA_NAME}.dr_linkki_k"
PGDUMP_OUTPUT="digiroad_k_$(date "+%Y-%m-%d").pgdump"
SHP2PGSQL="shp2pgsql -D -i -s 3067 -S -N abort -W UTF-8"

# Create digiroad schema into database.
docker exec "${DOCKER_CONTAINER_NAME}" sh -c "$PSQL -nt -c \"CREATE SCHEMA ${SCHEMA_NAME};\""

# Only creates a table based on one shapefile. Relies on `SHP_AREA` variable that is declared previously.
docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE_NAME \
  sh -c "$SHP2PGSQL -p /tmp/shp/${SHP_AREA}/${LINK_FILENAME} $TABLE_REF | $PSQL -v ON_ERROR_STOP=1 -q"

# Import links from multiple shapefiles into one database table.
docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE_NAME \
  sh -c "for SHP_AREA in ${SHP_AREAS}; do $SHP2PGSQL -a /tmp/shp/\${SHP_AREA}/${LINK_FILENAME} $TABLE_REF | $PSQL -v ON_ERROR_STOP=1; done"

# Process road geometries and filtering properties in database.
docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${CWD}/sql:/tmp/sql ${DOCKER_IMAGE_NAME} \
  sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_linkki_k.sql"

# Export pg_dump file as output.
docker run -it --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${WORK_DIR}/pgdump/:/tmp/pgdump $DOCKER_IMAGE_NAME \
  sh -c "$PG_DUMP -Fc --clean -f /tmp/pgdump/${PGDUMP_OUTPUT} --table $TABLE_REF"

# Stop Docker container.
docker stop $DOCKER_CONTAINER_NAME
