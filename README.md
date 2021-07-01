# jore4-digiroad-import-experiment

## Overview

This repository provides scripts to download Digiroad shapefiles for road geometries and make transformations required by JORE4 components/services.

Firstly, Digiroad links and other related information is downloaded and imported from shapefiles into a PostGIS database (contained in a Docker container) by executing an import script. Within import process and after downloading is finished, the data is further processed in the database. After import and processing stage, the data can be exported from the database in a couple of formats relevant to JORE4 services.

The database is used only locally for processing data. Each invocation of main import script will recreate the Docker container and reset the state of database.

## Usage

Initially, you need to build the Docker image containing PostGIS database with:

```
./build_docker_image.sh
```

Secondly, Digiroad shapefiles are downloaded and imported into PostGIS database inside a Docker container with further processing done by executing:

```
./import_digiroad_shapefiles.sh
```

A pg_dump file containing all data can be exported with (given that Digiroad material has already been imported):

```
./export_pgdump.sh
```

The exported pg_dump can be imported into a target database with:

```
./import_links_from_pgdump.sh
```

The above import script is given database connection details as arguments.

## Target database initialisation

Before importing pg_dump file into target database the database must be added postgis extension. E.g. the following commands create database and user named "digiroad" and add postgis extension to the newly-created database. Remember to set up passwords as you wish.

```
CREATE DATABASE digiroad;
CREATE USER digiroad;
GRANT ALL PRIVILEGES ON DATABASE digiroad TO digiroad;
\c digiroad
CREATE EXTENSION postgis;
```
