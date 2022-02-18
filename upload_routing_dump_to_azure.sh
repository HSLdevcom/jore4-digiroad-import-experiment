#!/usr/bin/env bash

# Azure CLI is required to be installed.
# NB: Not all versions of Azure CLI seem to work for uploading the files, see the error message below for more info.

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
if ! time az storage azcopy blob upload \
  --source "${SQL_FILE}" \
  --recursive \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --container "jore4-digiroad"; then
    cat <<EOF

Upload failed. Please make sure that you have installed a version of Azure CLI, which is known to work
(e.g. 2.29.2, may require downgrade).

Alternatively you may perform the upload manually in the azure portal (storage account "jore4storage", container
"jore4-digiroad").
EOF
    exit 2
fi

# List all artifacts inside `jore4-digiroad` in blob storage container.
az storage blob list \
  --container-name "jore4-digiroad" \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --query "[].name"
