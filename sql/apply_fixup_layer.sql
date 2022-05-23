-- Add `link_id` attribute whose value is derived from the primary key of GeoPackage layer (`fid`).
ALTER TABLE :schema.fix_layer_link ADD COLUMN link_id text;

-- Add internal ID for SQL view. Values will be derived from the primary key of GeoPackage layer
-- (`fid`).
ALTER TABLE :schema.fix_layer_link ADD COLUMN internal_id int;

-- Force separate ID value spaces for fixup data.
UPDATE :schema.fix_layer_link
SET link_id     = 'hsl_' || fid,
    internal_id =  1000000000 + fid;  -- add one billion (US)

ALTER TABLE :schema.fix_layer_link
    ALTER COLUMN link_id SET NOT NULL,
    ALTER COLUMN internal_id SET NOT NULL;

-- 
-- Create link table between tables `dr_linkki` and `fix_layer_link_exclusion_geometry`.
-- 

DROP TABLE IF EXISTS :schema.fix_layer_link_exclusion;

CREATE TABLE :schema.fix_layer_link_exclusion AS
SELECT l.link_id, exg.fid AS geometry_fid
FROM :schema.fix_layer_link_exclusion_geometry exg
INNER JOIN :schema.dr_linkki l ON ST_Intersects(l.geom, exg.geom);

-- Add data integrity constraints.
ALTER TABLE :schema.fix_layer_link_exclusion

    ALTER COLUMN link_id SET NOT NULL,
    ALTER COLUMN geometry_fid SET NOT NULL,

    ADD CONSTRAINT fix_layer_link_exclusion_pkey PRIMARY KEY (link_id, geometry_fid),
    ADD CONSTRAINT fk_fix_layer_link_exclusion_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_linkki (link_id),
    ADD CONSTRAINT fk_fix_layer_link_exclusion_geometry_fid FOREIGN KEY (geometry_fid) REFERENCES :schema.fix_layer_link_exclusion_geometry (fid);

-- 
-- Create SQL views intended to be used (when exporting data) instead of tables imported from
-- shapefiles.
-- 
-- Custom `hsl_infra_source` column is added with supported values being:
--   "digiroad_r"
--   "hsl_fixup"
-- 
-- Boolean-valued columns for supported vehicle modes/types within Jore4 are added.
-- 

CREATE VIEW :schema.dr_linkki_fixup AS
SELECT
    id,
    link_id,
    kuntakoodi,
    linkkityyp,
    link_tila,
    ajosuunta,
    silta_alik,
    tienimi_su,
    tienimi_ru,
    'digiroad_r'::text AS hsl_infra_source,
    true AS is_generic_bus,
    -- TODO: Assign "tall electric bus" vehicle type based on greatest allowed height property.
    false AS is_tall_electric_bus,
    false AS is_tram,
    false AS is_train,
    false AS is_metro,
    linkkityyp = 21 AS is_ferry,
    geom
FROM :schema.dr_linkki l
WHERE NOT EXISTS (
    SELECT 1
    FROM :schema.fix_layer_link_exclusion ex
    WHERE ex.link_id = l.link_id
)
UNION
SELECT
    internal_id AS id,
    link_id,
    kuntakoodi,
    linkkityyp,
    NULL AS link_tila,
    ajosuunta,
    silta_alik,
    tienimi_su,
    tienimi_ru,
    'hsl_fixup'::text AS hsl_infra_source,
    is_generic_bus,
    is_tall_electric_bus,
    is_tram,
    is_train,
    is_metro,
    is_ferry,
    geom
FROM :schema.fix_layer_link fl
WHERE
    -- filter out incorrect driving directions
    ajosuunta IN (2, 3, 4)
    AND NOT EXISTS (
        -- sanity check to guarantee non-overlapping IDs between two queries combined with UNION
        -- operator
        SELECT 1
        FROM :schema.dr_linkki l
        WHERE l.id = fl.internal_id
    );

CREATE VIEW :schema.dr_pysakki_fixup AS
SELECT p.*
FROM :schema.dr_pysakki p
INNER JOIN :schema.dr_linkki_fixup l ON p.link_id = l.link_id;
