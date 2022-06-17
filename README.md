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

## JORE4 fix layer on top of Digiroad links (a.k.a. _QGIS fixup layer_)

JORE4 project involves a "QGIS fixup layer" in the form of QGIS project. The
project file (`fixup/jore4-digiroad-fix-project.qgs`) contains several layers or layer groups:
* Background map tiles from an online service (currently Digitransit)
* Digiroad infrastructure links (_DR_LINKKI_) from shapefiles covering Uusimaa (administrative region)
* Digiroad public transport stops (_DR_PYSAKKI_) from shapefiles covering Uusimaa (administrative region)
* JORE4 fix layer

With _JORE4 fix layer_ HSL-specific customisations to infrastructure network can
be achieved. In JORE4, there is a need for more fine-grained infrastructure link
modeling at some places (e.g. public transport terminals) than what Digiroad
(eventually
[Maastotietokanta](https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/expert-users/product-descriptions/topographic-database)
of [MML](https://www.maanmittauslaitos.fi/en)) currently provides. These
customisations can be defined in the fix layer of the QGIS project.

JORE4 fix layer in the QGIS project is actually a QGIS layer group consisting
of the QGIS layers that are described in the table below. The data for these
layers is stored in and read from a separate GeoPackage file
(`fixup/digiroad/fixup.gpkg`). This GeoPackage file will be updated and
maintained in the daily operational use of JORE4 "ecosystem".

| QGIS layer       | Description |
| ---------------- | ----------- |
| `add_link`       | Contains data for HSL-specific infrastructure links to be added on top of or to replace existing Digiroad links (the latter case in tandem with `remove_link` layer). A `LINESTRING` geometry is a mandatory part of each link to be added. All the geometries defined on this layer must seamlessly join to each other and/or existing Digiroad links. Seamlessness can be achieved by using the _Snapping Tool_ in QGIS while drawing line features. |
| `remove_link`    | Contains geometries that are used to mark intersecting Digiroad links for removal. The links marked for removal will be filtered out when exporting data in later stages. The Digiroad public transport stops along the links marked for removal are also filtered out in data exports. It is recommended to use `LINESTRING` type in intersection geometries but currently this is not strictly required. |
| `add_stop_point` | Contains data for HSL-defined public transport stop points that are mainly used to replace the ones available in Digiroad. A `POINT` geometry is a mandatory part of each stop point to be added as well as `valtak_id` attribute that denotes so called _ELY number_. The closest infrastructure link to each stop point and other information is resolved automatically during import process. |

### GeoPackage _add_link_ layer contents

The table below describes the columns of the `add_link` layer in the QGIS
project. The data types are as they appear in the GeoPackage format (SQLite).

| Column name            | Data type  | Not null | Description |
| ---------------------- | ---------- | -------- | ----------- |
| `fid`                  | INTEGER    | X        | The primary key generated internally in GeoPackage. The integer value is used to derive `LINK_ID` attribute within processing of data. |
| `geom`                 | LINESTRING | X        | The `LINESTRING` geometry describing the shape of this infrastructure link |
| `kuntakoodi`           | MEDIUMINT  | -        | Official Finnish municipality code |
| `linkkityyp`           | MEDIUMINT  | -        | The link type as code value from the corresponding Digiroad code set |
| `ajosuunta`            | MEDIUMINT  | X        | The direction of traffic flow as code value from the corresponding Digiroad code set |
| `silta_alik`           | MEDIUMINT  | -        | Is this infrastructure link a bridge, tunnel or underpass? The value must be selected from the corresponding Digiroad code set. |
| `tienimi_su`           | TEXT       | -        | The name of infrastructure link in Finnish |
| `tienimi_ru`           | TEXT       | -        | The name of infrastructure link in Swedish |
| `is_generic_bus`       | BOOLEAN    | -        | Is this infrastructure link safely traversable by _generic_bus_ vehicle type? |
| `is_tall_electric_bus` | BOOLEAN    | -        | Is this infrastructure link safely traversable by _tall_electric_bus_ vehicle type? |
| `is_tram`              | BOOLEAN    | -        | Is this infrastructure link traversable by tram? |
| `is_train`             | BOOLEAN    | -        | Is this infrastructure link traversable by train? |
| `is_metro`             | BOOLEAN    | -        | Is this infrastructure link traversable by metro? |
| `is_ferry`             | BOOLEAN    | -        | Is this infrastructure link traversable by ferry? |

### GeoPackage _remove_link_ layer contents

The table below describes the columns of the `remove_link` layer in the QGIS
project. The data types are as they appear in the GeoPackage format (SQLite).

| Column name | Data type | Not null | Description |
| ----------- | --------- | -------- | ----------- |
| `fid`       | INTEGER   | X        | The primary key generated internally in GeoPackage |
| `geom`      | GEOMETRY  | X        | The geometry used to find all infrastructure links whose geometry intersects with it. The affected infrastructure links will be marked for removal and will not be included in data exports. | 

### GeoPackage _add_stop_point_ layer contents

The table below describes the columns of the `add_stop_point` layer in the QGIS
project. The data types are as they appear in the GeoPackage format (SQLite).

| Column name | Data type  | Not null | Description |
| ----------- | ---------- | -------- | ----------- |
| `fid`       | INTEGER    | X        | The primary key generated internally in GeoPackage. |
| `geom`      | POINT      | X        | The `POINT` geometry describing the location of this public transport stop point |
| `valtak_id` | INTEGER    | X        | The national ID for the stop point that is also known as _ELY number_ |
| `matk_tunn` | TEXT       | -        | The passenger ID for the stop point e.g. H1234 |
| `nimi_su`   | TEXT       | -        | The name of stop point in Finnish |
| `nimi_ru`   | TEXT       | -        | The name of stop point in Swedish |

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
