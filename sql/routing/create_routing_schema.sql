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

-- Add data integrity constraints to dr_linkki table after copying it from source schema.
\i :sql_dir/add_dr_linkki_constraints.sql

-- Add columns required by pgRouting extension.
SELECT AddGeometryColumn(:'schema', 'dr_linkki', 'geom', 3067, 'LINESTRING', 2);
ALTER TABLE :schema.dr_linkki ADD COLUMN source INTEGER,
                              ADD COLUMN target INTEGER,
                              ADD COLUMN cost FLOAT,
                              ADD COLUMN reverse_cost FLOAT;

-- Create indices to improve performance of pgRouting.
CREATE INDEX dr_linkki_geom_idx ON :schema.dr_linkki USING GIST(geom);
CREATE INDEX dr_linkki_source_idx ON :schema.dr_linkki (source);
CREATE INDEX dr_linkki_target_idx ON :schema.dr_linkki (target);

-- Populate `geom` column before topology creation.
-- Note that pgRouting requires a 2D geometry.
UPDATE :schema.dr_linkki SET geom = ST_Force2D(geom_3d);

-- Create pgRouting topology.
-- Need to use `gid` as ID column instead of `link_id` because pgRouting requires integer based ID column.
SELECT pgr_createTopology(:'schema' || '.dr_linkki', 0.001, 'geom', 'gid');

-- Set up `cost` and `reverse_cost` parameters for pgRouting functions.
-- 
-- Valid `ajosuunta` values are:
--  `2` ~ bidirectional
--  `3` ~ against digitised direction
--  `4` ~ along digitised direction
-- 
-- Negative `cost` effectively means pgRouting will not consider traversing the link along its digitised direction.
-- Correspondingly, negative `reverse_cost` means pgRouting will not consider traversing the link against its
-- digitised direction. Hence, with `cost` and `reverse_cost` we can (in addition to their main purpose) define
-- one-way directionality constraints for road links.
-- 
-- TODO: Do cost calculation based on speed limits.
UPDATE :schema.dr_linkki SET
    cost = CASE WHEN ajosuunta IN (2,4) THEN ST_Length(geom_3d) ELSE -1 END,
    reverse_cost = CASE WHEN ajosuunta IN (2,3) THEN ST_Length(geom_3d) ELSE -1 END;

ALTER TABLE :schema.dr_linkki ALTER COLUMN geom SET NOT NULL,
                              ALTER COLUMN source SET NOT NULL,
                              ALTER COLUMN target SET NOT NULL,
                              ALTER COLUMN cost SET NOT NULL,
                              ALTER COLUMN reverse_cost SET NOT NULL;

-- Drop 3D geometry since it cannot be utilised by pgRouting.
ALTER TABLE :schema.dr_linkki DROP COLUMN geom_3d;

-- Copy `dr_pysakki` table from digiroad schema and add relevant constraints.
CREATE TABLE :schema.dr_pysakki (LIKE :source_schema.dr_pysakki);
INSERT INTO :schema.dr_pysakki SELECT * FROM :source_schema.dr_pysakki;
\i :sql_dir/add_dr_pysakki_constraints.sql
