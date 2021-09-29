#!/usr/bin/env bash

# Azure CLI is required to be installed.

# The target file is an SQL dump file for routing schema for current date.
SQL_FILE="./workdir/pgdump/digiroad_r_routing_$(date "+%Y-%m-%d").sql"

if [[ ! -f "${SQL_FILE}" ]]; then
    echo "File to upload does not exist: ${SQL_FILE}"
    exit 1
fi

# Login to Azure.
az login
az account set --subscription "jore4"

# Upload dump file to Azure Blob Storage.
time az storage azcopy blob upload \
  --source "${SQL_FILE}" \
  --recursive \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --container "jore4-digiroad"

# List all artifacts inside `jore4-digiroad` in blob storage container.
az storage blob list \
  --container-name "jore4-digiroad" \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --query "[].name"
