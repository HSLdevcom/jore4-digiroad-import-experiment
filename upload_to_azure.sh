#!/usr/bin/env bash

# Login to Azure
az login
az account set --subscription "jore4"

# Upload digiroad routing sql file to blob storage
time az storage azcopy blob upload \
  --source "./workdir/output/digiroad_r_routing*.sql" \
  --recursive \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --container "jore4-digiroad"

# List all digiroad export files in blob storage
az storage blob list \
  --container-name "jore4-digiroad" \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --query "[].name"