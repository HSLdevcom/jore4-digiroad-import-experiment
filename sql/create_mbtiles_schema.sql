DROP SCHEMA IF EXISTS :schema CASCADE;

CREATE SCHEMA :schema;

CREATE TABLE :schema.dr_linkki_k AS
SELECT
    src.gid,
    src.link_id,
    src.segm_id,
    src.geom AS geom_orig
FROM :source_schema.dr_linkki_k src;

-- Apply geometry conversion suitable for MVT format.
SELECT AddGeometryColumn(:'schema', 'dr_linkki_k', 'geom', 4326, 'LINESTRING', 2);
UPDATE :schema.dr_linkki_k SET geom = ST_Transform(ST_Force2D(geom_orig), 4326);
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_linkki_k DROP COLUMN geom_orig;

-- Add data integrity constraints to dr_linkki_k table.
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN link_id SET NOT NULL;
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN segm_id SET NOT NULL;

ALTER TABLE :schema.dr_linkki_k ADD CONSTRAINT dr_linkki_k_pkey PRIMARY KEY (gid);
ALTER TABLE :schema.dr_linkki_k ADD CONSTRAINT uk_dr_linkki_k_segm_id UNIQUE (segm_id);
