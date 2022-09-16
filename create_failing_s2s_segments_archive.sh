#!/usr/bin/env bash

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Create a zip archive containing failing stop-to-stop segments.
mkdir -p $WORK_DIR/zip  

zip -r "${WORK_DIR}/zip/$(date "+%Y-%m-%d")_failing_stop2stop_segments.zip" \
  fixup/jore4-digiroad-issues.qgz \
  fixup/digiroad/failed_segment* \
  workdir/shp/UUSIMAA/DR_PYSAKKI* \
  workdir/shp/UUSIMAA/ITA-UUSIMAA/DR_LINKKI* \
  workdir/shp/UUSIMAA/UUSIMAA_1/DR_LINKKI* \
  workdir/shp/UUSIMAA/UUSIMAA_2/DR_LINKKI*
