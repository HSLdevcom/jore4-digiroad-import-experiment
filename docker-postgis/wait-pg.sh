#!/usr/bin/env bash

DB_NAME="$1"
DB_HOST="$2"
DB_PORT="$3"

echo -n "Waiting for PostgreSQL to start."

while ! pg_isready -d "${DB_NAME}" -h "${DB_HOST}" -p "${DB_PORT}" &> /dev/null
do
    echo -n "."
    sleep 0.2
done

echo
echo "PostgreSQL is now ready!"
