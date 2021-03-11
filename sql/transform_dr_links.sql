DROP TABLE IF EXISTS digiroad_import.dr_links;

CREATE TABLE digiroad_import.dr_links AS
SELECT
    src.gid AS gid,
    src.link_id AS digiroad_id,
    src.link_mmlid AS mml_id,
    src.tienimi_su AS road_name_fi,
    src.tienimi_ru AS road_name_sv,
    (ST_Dump(src.geom)).geom AS geom_dump
FROM digiroad_import.dr_links_in src
WHERE src.kuntakoodi IN (
     -- Include HSL member municipalities (currently, three of them not yet included) 
     49, -- Espoo,
     91, -- Helsinki
    235, -- Kauniainen
    245, -- Kerava
         -- Kirkkonummi
         -- Sipoo
         -- Siuntio
    858, -- Tuusula
     92  -- Vantaa
);

UPDATE digiroad_import.dr_links SET geom_dump = ST_SetSRID(geom_dump, 3067);

SELECT AddGeometryColumn('digiroad_import', 'dr_links', 'geom', 3067, 'LINESTRING', 3);
UPDATE digiroad_import.dr_links SET geom = ST_Force3D(geom_dump);
ALTER TABLE digiroad_import.dr_links ALTER COLUMN geom SET NOT NULL;

ALTER TABLE digiroad_import.dr_links DROP COLUMN geom_dump;

ALTER TABLE digiroad_import.dr_links ADD COLUMN geog geography(LINESTRINGZ, 4326);
UPDATE digiroad_import.dr_links SET geog = Geography(ST_Transform(geom, 4326));
ALTER TABLE digiroad_import.dr_links ALTER COLUMN geog SET NOT NULL;
