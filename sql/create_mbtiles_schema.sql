DROP SCHEMA IF EXISTS :schema CASCADE;

CREATE SCHEMA :schema;

CREATE TABLE :schema.dr_linkki AS
SELECT
    src.id,
    src.link_id,
    src.geom AS geom_orig
FROM :source_schema.dr_linkki_fixup src;

-- Apply geometry conversion for dr_linkki table that is suitable for MVT format.
SELECT AddGeometryColumn(:'schema', 'dr_linkki', 'geom', 4326, 'LINESTRING', 2);
UPDATE :schema.dr_linkki SET geom = ST_Transform(ST_Force2D(geom_orig), 4326);
ALTER TABLE :schema.dr_linkki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_linkki DROP COLUMN geom_orig;

-- Copy dr_pysakki table from source schema.
CREATE TABLE :schema.dr_pysakki AS
SELECT
    src.id,
    src.link_id,
    src.kuntakoodi,
    src.koord_x,
    src.koord_y,
    src.geom AS geom_orig
FROM :source_schema.dr_pysakki_fixup src;

-- Apply geometry conversion for dr_pysakki table that is suitable for MVT format.
SELECT AddGeometryColumn(:'schema', 'dr_pysakki', 'geom', 4326, 'POINT', 2);
UPDATE :schema.dr_pysakki SET geom = ST_Transform(ST_Force2D(geom_orig), 4326);
ALTER TABLE :schema.dr_pysakki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_pysakki DROP COLUMN geom_orig;

-- Add data integrity constraints to dr_linkki table.
ALTER TABLE :schema.dr_linkki ALTER COLUMN link_id SET NOT NULL;

ALTER TABLE :schema.dr_linkki ADD CONSTRAINT dr_linkki_pkey PRIMARY KEY (id);
ALTER TABLE :schema.dr_linkki ADD CONSTRAINT uk_dr_linkki_link_id UNIQUE (link_id);

-- Add data integrity constraints to dr_pysakki table.
ALTER TABLE :schema.dr_pysakki ALTER COLUMN id SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN link_id SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN kuntakoodi SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN koord_x SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN koord_y SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_pysakki ADD CONSTRAINT dr_pysakki_pkey PRIMARY KEY (id);
ALTER TABLE :schema.dr_pysakki ADD CONSTRAINT fk_dr_pysakki_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_linkki (link_id);
