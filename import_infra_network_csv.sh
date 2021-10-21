#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Reading connection parameters
echo "Please fill in the connection parameters for the database to import the data to:"
read -p "Hostname (default: localhost): " PGHOSTNAME
PGHOSTNAME="${PGHOSTNAME:-localhost}"
read -p "Database name (default: jore4e2e): " PGDATABASE
PGDATABASE="${PGDATABASE:-jore4e2e}"
read -p "Port (default: 6432): " PGPORT
PGPORT="${PGPORT:-6432}"
read -p "Username (default: dbadmin): " PGUSERNAME
PGUSERNAME="${PGUSERNAME:-dbadmin}"
read -p "Password (default: adminpassword): " PGPASSWORD
PGPASSWORD="${PGPASSWORD:-adminpassword}"

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Import dump from csv file.
INPUT_FILENAME="infra_network_digiroad.csv"
PGPASSWORD="${PGPASSWORD}" psql -h "${PGHOSTNAME}" -p "${PGPORT}" -U "${PGUSERNAME}" -d "${PGDATABASE}" \
  -v ON_ERROR_STOP=1 -f ${CWD}/sql/import_infra_links_from_csv.sql -v csvfile="${WORK_DIR}/csv/${INPUT_FILENAME}"
