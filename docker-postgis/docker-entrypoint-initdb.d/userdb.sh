#!/bin/bash

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER digiroad;
    CREATE DATABASE digiroad;
    GRANT ALL PRIVILEGES ON DATABASE digiroad TO digiroad;
    \c digiroad
    CREATE EXTENSION postgis;
    CREATE EXTENSION pgrouting;
EOSQL
