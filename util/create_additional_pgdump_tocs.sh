#!/usr/bin/env bash

PGDUMP_FILE="$1"
PGDUMP_TOC="${PGDUMP_FILE}.list"

if [[ ! -f "${PGDUMP_TOC}" ]]; then
    echo "A pg_dump toc file not found: ${PGDUMP_TOC}"
    exit 1
fi

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# When passing this toc file as an argument to `pg_restore` command, only data
# is restored (no table definitions). Data for enumeration tables is excluded
# because those are already included in the database migration scripts of the
# map-matching backend. Public transport stops are also excluded.
PGDUMP_TOC_ONLY_LINKS_NO_ENUMS="${PGDUMP_FILE}.no-enums.only-links.list"

fgrep "TABLE DATA routing infrastructure_source " ${PGDUMP_TOC} > ${PGDUMP_TOC_ONLY_LINKS_NO_ENUMS}
fgrep "TABLE DATA routing infrastructure_link " ${PGDUMP_TOC} >> ${PGDUMP_TOC_ONLY_LINKS_NO_ENUMS}
fgrep "TABLE DATA routing infrastructure_link_vertices_pgr " ${PGDUMP_TOC} >> ${PGDUMP_TOC_ONLY_LINKS_NO_ENUMS}
fgrep "TABLE DATA routing infrastructure_link_safely_traversed_by_vehicle_type " ${PGDUMP_TOC} >> ${PGDUMP_TOC_ONLY_LINKS_NO_ENUMS}
fgrep "SEQUENCE SET routing infrastructure_link_vertices_pgr_id_seq " ${PGDUMP_TOC} >> ${PGDUMP_TOC_ONLY_LINKS_NO_ENUMS}

# When passing this toc file as an argument to `pg_restore` command, only data
# is restored (no table definitions). Data for enumeration tables is excluded
# because those are already included in the database migration scripts of the
# map-matching backend.
PGDUMP_TOC_NO_ENUMS="${PGDUMP_FILE}.no-enums.links-and-stops.list"

cp ${PGDUMP_TOC_ONLY_LINKS_NO_ENUMS} ${PGDUMP_TOC_NO_ENUMS}
fgrep "TABLE DATA routing public_transport_stop " ${PGDUMP_TOC} >> ${PGDUMP_TOC_NO_ENUMS}
