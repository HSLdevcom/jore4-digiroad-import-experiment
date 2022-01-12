#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

AREA="UUSIMAA"

SHP_URL="https://ava.vaylapilvi.fi/ava/Tiest%C3%B6tiedot/Digiroad/Digiroad-irrotusaineistot/latest/Maakuntajako_DIGIROAD_R_EUREF-FIN/${AREA}.zip"

DOWNLOAD_TARGET_DIR="${WORK_DIR}/zip"
DOWNLOAD_TARGET_FILE="${DOWNLOAD_TARGET_DIR}/${AREA}_R.zip"

# Load zip file containing Digiroad shapefiles if it does not exist.
if [[ ! -f "$DOWNLOAD_TARGET_FILE" ]]; then
    mkdir -p "$DOWNLOAD_TARGET_DIR"
    curl -Lo $DOWNLOAD_TARGET_FILE $SHP_URL
fi

SUB_AREAS="ITA-UUSIMAA UUSIMAA_1 UUSIMAA_2"
SUB_AREA_SHP_TYPES="DR_LINKKI DR_KAANTYMISRAJOITUS"
SHP_FILE_DIR="${WORK_DIR}/shp/${AREA}"

for SUB_AREA in $SUB_AREAS
do
    for SUB_AREA_SHP_TYPE in $SUB_AREA_SHP_TYPES
    do
        if [[ ! -f "${SHP_FILE_DIR}/${SUB_AREA}/${SUB_AREA_SHP_TYPE}.shp" ]]; then
            mkdir -p "$SHP_FILE_DIR/${SUB_AREA}"
            # Extract shapefile.
            unzip -u $DOWNLOAD_TARGET_FILE ${SUB_AREA}/${SUB_AREA_SHP_TYPE}.* -d $SHP_FILE_DIR
        fi
    done
done

# Extract stop shapefile (common to Uusimaa).
if [[ ! -f "${SHP_FILE_DIR}/DR_PYSAKKI.shp" ]]; then
    unzip -u $DOWNLOAD_TARGET_FILE PYSAKIT.zip -d $DOWNLOAD_TARGET_DIR/$AREA
    unzip -u $DOWNLOAD_TARGET_DIR/${AREA}/PYSAKIT.zip -d $SHP_FILE_DIR
fi

# Remove possibly running/existing Docker container.
docker kill $DOCKER_CONTAINER &> /dev/null || true
docker rm -v $DOCKER_CONTAINER &> /dev/null || true

# Create and start new Docker container.
docker run --name $DOCKER_CONTAINER -e POSTGRES_HOST_AUTH_METHOD=trust -d $DOCKER_IMAGE

# Wait for PostgreSQL to start.
docker exec "${DOCKER_CONTAINER}" sh -c "$PG_WAIT_LOCAL"

# Create digiroad import schema into database.
docker exec "${DOCKER_CONTAINER}" sh -c "$PSQL -nt -c \"CREATE SCHEMA ${DB_IMPORT_SCHEMA_NAME};\""

SHP2PGSQL="shp2pgsql -D -i -s 3067 -S -N abort -W $SHP_ENCODING"

for SUB_AREA_SHP_TYPE in $SUB_AREA_SHP_TYPES
do
    # Derive lowercase table name for shape type.
    TABLE_NAME="${DB_IMPORT_SCHEMA_NAME}.`echo ${SUB_AREA_SHP_TYPE} | awk '{print tolower($0)}'`"

    # Create database table for each shape type.
    docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE \
      sh -c "$SHP2PGSQL -p /tmp/shp/${SUB_AREA}/${SUB_AREA_SHP_TYPE}.shp $TABLE_NAME | $PSQL -v ON_ERROR_STOP=1 -q"

    # Populate database table from multiple shapefiles from sub areas.
    docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE \
      sh -c "for SUB_AREA in ${SUB_AREAS}; do $SHP2PGSQL -a /tmp/shp/\${SUB_AREA}/${SUB_AREA_SHP_TYPE}.shp $TABLE_NAME | $PSQL -v ON_ERROR_STOP=1; done"
done

# Process road geometries and filtering properties in database.
docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${CWD}/sql:/tmp/sql \
  ${DOCKER_IMAGE} sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_linkki.sql -v schema=${DB_IMPORT_SCHEMA_NAME} -v sql_dir=/tmp/sql"

# Load DR_PYSAKKI shapefile into database.
docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${SHP_FILE_DIR}:/tmp/shp $DOCKER_IMAGE \
  sh -c "$SHP2PGSQL -c /tmp/shp/DR_PYSAKKI.shp ${DB_IMPORT_SCHEMA_NAME}.dr_pysakki | $PSQL -v ON_ERROR_STOP=1"

# Process stops and filter properties in database.
docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${CWD}/sql:/tmp/sql \
  ${DOCKER_IMAGE} sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_pysakki.sql -v schema=${DB_IMPORT_SCHEMA_NAME} -v sql_dir=/tmp/sql"

# Process turn restrictions and filter properties in database.
docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${CWD}/sql:/tmp/sql \
  ${DOCKER_IMAGE} sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_kaantymisrajoitus.sql -v schema=${DB_IMPORT_SCHEMA_NAME}"

# Create separate schema for exporting data in MBTiles format.
docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${CWD}/sql:/tmp/sql \
  ${DOCKER_IMAGE} sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/create_mbtiles_schema.sql -v source_schema=${DB_IMPORT_SCHEMA_NAME} -v schema=${DB_MBTILES_SCHEMA_NAME} -v sql_dir=/tmp/sql"

# Stop Docker container.
docker stop $DOCKER_CONTAINER
