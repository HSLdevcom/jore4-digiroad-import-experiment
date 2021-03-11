# jore4-digiroad-import-experiment

## Overview

Experiment with importing Digiroad links from shapefiles.

This repository provides scripts to download Digiroad shapefiles for road geometries, transforming them to a JORE4 compatible pg_dump format and importing them into a database. 

## Usage

Initially, you need to build the Docker image containing PostGIS database with:

```
./build-tool-images.sh
```

Secondly, Digiroad shapefile can be downloaded and processed into a pg_dump file with:

```
./create-digiroad-pgdump.sh
```

Thirdly, a pg_dump file created in previous step can be imported into a database with:

```
./import-digiroad-links.sh
```

The import script can be given database connection details as arguments.
