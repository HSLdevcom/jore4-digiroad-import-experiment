# jore4-digiroad-import

## Overview

This repository provides scripts to download
[Digiroad](https://vayla.fi/en/transport-network/data/digiroad) shapefiles for
road and public transport stop geometries and make transformations required by
JORE4 microservices.

Firstly, Digiroad road links, public transport stops and other related data is
downloaded and imported from shapefiles into a PostGIS database (contained in a
Docker container) by executing the import script
(`import_digiroad_shapefiles.sh`). During execution of the import script data is
further processed in the database after which the data can be exported in a
couple of formats relevant to various JORE4 services.

The database is used only locally for processing data. Each invocation of the
import script will recreate the Docker container and reset the state of
database used for data processing.

## Building Docker image

Almost all the of the data processing will be done inside a Docker container.
The Docker container contains a PostGIS database enabled with pgRouting
extension.

The Docker image for the container is built with:

```sh
./build_docker_image.sh
```

## Importing data from Digiroad

Initially, Digiroad shapefiles are downloaded and imported into PostGIS database
of the Docker container by running:

```sh
./import_digiroad_shapefiles.sh
```

The shapefiles are, by default, imported into a database schema named `digiroad`.
The schema name can be changed in `set_env_vars.sh` script.

Within the script execution further processing for Digiroad data is done as well.

## Exporting Digiroad data

```sh
./export_pgdump_digiroad.sh
```

Before importing pg_dump file for Digiroad schema into target database the
database must have `postgis` extension. E.g. the following commands create
a database and user named `digiroad` and add `postgis` extension to the
newly-created database. Remember to set up passwords as you wish.

```sql
CREATE DATABASE digiroad;
CREATE USER digiroad;
GRANT ALL PRIVILEGES ON DATABASE digiroad TO digiroad;
\c digiroad
CREATE EXTENSION postgis;
```

At the moment, there is no specific use case within JORE4 for the dump generated
with the above command. However, it is planned that a separate schema will be
generated later that will contain the infrastructure tables and columns used in
JORE4 database.

## Exporting routing schema

One can export the schema definitions and/or table data for [JORE4 navigation
and map-matching backend](https://github.com/HSLdevcom/jore4-map-matching).

By executing `export_routing_schema.sh`, a separate routing schema is created
in the database. The data is read from the Digiroad schema and is transformed
into a table structure defined in and used by the JORE4 map-matching backend.
As a result, two database dump files will be created: one in SQL format, named
`digiroad_r_routing_<date>.sql`, and another in PostgreSQL's custom format,
named `digiroad_r_routing_<date>.pgdump`. Both files will be written into
`workdir/pgdump` subdirectory.

The SQL dump artifact can be uploaded to Azure Blob Storage with the command
below. An active Azure subscription associated with JORE4 is required. Azure CLI
is also required to be installed. In addition, the SQL dump file needs to be
created on current day.

```sh
./upload_routing_dump_to_azure.sh
```

A couple of toc list (table of contents) files are generated as sidecars to the
custom-format dump file. A toc file may be passed as an argument to `pg_restore`
command. The toc files can be used to selectively apply what is being restored
from the dump, e.g. the entire schema with data or table data for selected tables
only.

The table below describes the contents of each toc file generated.

| ToC file                                                         | Description                              |
| ---------------------------------------------------------------- | -----------------------------------------|
| `digiroad_r_routing_<date>.pgdump.list`                          | Contains entire routing schema and data. |
| `digiroad_r_routing_<date>.pgdump.no-enums.links-and-stops.list` | No schema item definitions at all. Contains table data for infrastructure links, topology and public transport stops. Does not include data for enum tables which is already included in the database migration scripts of the map-matching backend. |
| `digiroad_r_routing_<date>.pgdump.no-enums.only-links.list`      | No schema item definitions at all. Contains table data for infrastructure links and topology. Does not include public transport stops. Does not include data for enum tables which is already included in the database migration scripts of the map-matching backend. |

Which one should be used will depend on what deployment strategy with regard to
database migrations and data population is currently chosen in the map-matching
backend. Have a look at [README of map-matching backend](https://github.com/HSLdevcom/jore4-map-matching/blob/main/README.md)
for more details.

The target database is required to have `postgis` and `pgrouting` extensions.

## Exporting infrastructure links for JORE4

To export a CSV containing intrastructure network links' data, run:

```sh
./export_infra_network_csv.sh
```

You may import this CSV data into an existing database adhering to JORE4 schema,
using the command below. Note that `infrastructure_network.infrastructure_link`
table (and schema) has to exist in the target database. Also note that the
importer user must have read-write permissions to this table.

The script will interactively ask for the connection parameters of the target
database. They default to the parameters defined in the `jore4-flux` repository
for the `jore4e2e` database. You may set up the `jore4e2e` database locally with
the `./start_dependencies.sh` script.

Note: This script is currently only a proof of concept. It will create new links
if they didn't exist or update them if they do. But links deleted in digiroad
won't be deleted here.

```sh
./import_infra_network_csv.sh
```

## Exporting stops for JORE3 Importer

If you want to export Digiroad public transport stops as a CSV file to used with
[JORE3 Importer](https://github.com/HSLdevcom/jore4-jore3-importer), you have to
run:

```sh
./export_stops_csv.sh

```

This command reads selected data items from filtered public transport stop data
imported from Digiroad and writes it to the _workdir/csv/digiroad_stops.csv_
file.

## Exporting vector tiles

An MBTiles files containing filtered Digiroad road links can be exported with
(assuming Digiroad shapefiles have already been imported):

```sh
./export_mbtiles_dr_linkki.sh
```

An MBTiles files containing filtered Digiroad public transport stops can be
exported with (assuming Digiroad shapefiles have already been imported):

```sh
./export_mbtiles_dr_pysakki.sh
```

## License

The project license is in [`LICENSE`](./LICENSE).

Digiroad data has been licensed with Creative Commons BY 4.0 license by the
[Finnish Transport Infrastructure Agency](https://vayla.fi/en/transport-network/data/digiroad/data).

The Jore4 fix layer in [`./fixup`](./fixup) is licensed under Creative Commons
BY 4.0 by Helsinki Regional Transport Authority (HSL).
