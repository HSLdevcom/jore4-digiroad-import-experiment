#!/usr/bin/env bash

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Create a zip archive containing HSL QGIS fixup project.
mkdir -p $WORK_DIR/zip  
zip -r "${WORK_DIR}/zip/$(date "+%Y-%m-%d")_hsl_qgis_fixup_project.zip" \
  fixup/jore4-digiroad-fix-project.qgz \
  fixup/digiroad workdir/shp/UUSIMAA/
