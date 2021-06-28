DROP SCHEMA IF EXISTS :schema CASCADE;

CREATE SCHEMA :schema;

CREATE TABLE :schema.dr_linkki AS
SELECT
    src.gid,
    src.link_id,
    src.geom AS geom_orig
FROM :source_schema.dr_linkki src;

-- Apply geometry conversion suitable for MVT format.
SELECT AddGeometryColumn(:'schema', 'dr_linkki', 'geom', 4326, 'LINESTRING', 2);
UPDATE :schema.dr_linkki SET geom = ST_Transform(ST_Force2D(geom_orig), 4326);
ALTER TABLE :schema.dr_linkki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_linkki DROP COLUMN geom_orig;

-- Add data integrity constraints to dr_linkki table.
ALTER TABLE :schema.dr_linkki ALTER COLUMN link_id SET NOT NULL;

ALTER TABLE :schema.dr_linkki ADD CONSTRAINT dr_linkki_pkey PRIMARY KEY (gid);
ALTER TABLE :schema.dr_linkki ADD CONSTRAINT uk_dr_linkki_link_id UNIQUE (link_id);
