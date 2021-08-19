DROP SCHEMA IF EXISTS :schema CASCADE;

CREATE SCHEMA :schema;

CREATE TABLE :schema.dr_linkki AS
SELECT
    src.gid,
    src.link_id,
    src.kuntakoodi,
    src.linkkityyp,
    src.ajosuunta,
    src.link_tila,
    src.tienimi_su,
    src.tienimi_ru,
    src.tienimi_sa,
    ST_Force3D(src.geom) AS geom_3d
FROM :source_schema.dr_linkki src;

ALTER TABLE :schema.dr_linkki ADD COLUMN source INTEGER;
ALTER TABLE :schema.dr_linkki ADD COLUMN target INTEGER;

ALTER TABLE :schema.dr_linkki ADD COLUMN cost FLOAT;
ALTER TABLE :schema.dr_linkki ADD COLUMN reverse_cost FLOAT;

-- Add 2D geometry to be used with pgRouting extension.
SELECT AddGeometryColumn(:'schema', 'dr_linkki', 'geom', 3067, 'LINESTRING', 2);
UPDATE :schema.dr_linkki SET geom = ST_Force2D(geom_3d);
ALTER TABLE :schema.dr_linkki ALTER COLUMN geom SET NOT NULL;

-- Add data integrity constraints to dr_linkki table.
\i :sql_dir/add_dr_linkki_constraints.sql

-- Copy dr_pysakki table from digiroad schema and add constraints.
CREATE TABLE :schema.dr_pysakki (LIKE :source_schema.dr_pysakki);
INSERT INTO :schema.dr_pysakki SELECT * FROM :source_schema.dr_pysakki;
\i :sql_dir/add_dr_pysakki_constraints.sql

-- Create pgRouting topology.

CREATE INDEX dr_linkki_geom_idx ON :schema.dr_linkki USING GIST(geom);
CREATE INDEX dr_linkki_source_idx ON :schema.dr_linkki (source);
CREATE INDEX dr_linkki_target_idx ON :schema.dr_linkki (target);

-- Need to use `gid` as ID column instead of `link_id` because pgRouting requires integer based ID column.
SELECT pgr_createTopology(:'schema' || '.dr_linkki', 0.001, 'geom', 'gid');
ALTER TABLE :schema.dr_linkki ALTER COLUMN source SET NOT NULL;
ALTER TABLE :schema.dr_linkki ALTER COLUMN target SET NOT NULL;

-- Set up cost and reverse_cost parameters for pgRouting functions.
-- TODO: Do cost calculation based on speed limits.

UPDATE :schema.dr_linkki
SET cost = (
    CASE
        WHEN ajosuunta IN (2,4) THEN ST_Length(geom_3d)
        ELSE -1
    END
);

UPDATE :schema.dr_linkki
SET reverse_cost = (
    CASE
        WHEN ajosuunta IN (2,3) THEN ST_Length(geom_3d)
        ELSE -1
    END
);

ALTER TABLE :schema.dr_linkki ALTER COLUMN cost SET NOT NULL;
ALTER TABLE :schema.dr_linkki ALTER COLUMN reverse_cost SET NOT NULL;

ALTER TABLE :schema.dr_linkki DROP COLUMN geom_3d;
