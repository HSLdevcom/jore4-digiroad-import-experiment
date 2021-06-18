# jore4-digiroad-import-experiment

## Overview

Experiment with importing Digiroad links from shapefiles.

This repository provides scripts to download Digiroad shapefiles for road geometries, transforming them to a JORE4 compatible pg_dump format and importing them into a database. 

## Usage

Initially, you need to build the Docker image containing PostGIS database with:

```
./build_docker_image.sh
```

Secondly, Digiroad shapefile can be downloaded and processed into a pg_dump file with:

```
./create_digiroad_pgdump.sh
```

Thirdly, a pg_dump file created in previous step can be imported into a database with:

```
./import_digiroad_links.sh
```

The import script can be given database connection details as arguments.

## Target database initialisation

Before importing pg_dump file into target database the database must be added postgis extension. E.g. the following commands create database and user named "digiroad" and add postgis extension to the newly-created database. Remember to set up passwords as you wish.

```
CREATE DATABASE digiroad;
CREATE USER digiroad;
GRANT ALL PRIVILEGES ON DATABASE digiroad TO digiroad;
\c digiroad
CREATE EXTENSION postgis;
```
