#!/usr/bin/env bash

# Login to Azure
az login
az account set --subscription "jore4"

# Upload infra network dumps to blob storage
time az storage azcopy blob upload \
  --source "./workdir/output/infra_network_digiroad_*.json" \
  --recursive \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --container "jore4-digiroad"

# List all sql files in blob storage
az storage blob list \
  --container-name "jore4-digiroad" \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --query "[].name"
