-- Add `link_id` attribute whose value is derived from the primary key of GeoPackage layer (`fid`).
ALTER TABLE :schema.fix_layer_link ADD COLUMN link_id text;

-- Add internal ID for SQL view. Values will be derived from the primary key of GeoPackage layer
-- (`fid`).
ALTER TABLE :schema.fix_layer_link ADD COLUMN internal_id int;

-- Force separate ID value spaces for custom fixup links.
-- 
-- `link_id` attribute is changed to be derived from the `fid` column of GeoPackage (primary key).
-- Hence, there is no need to verify uniqueness separately. However, this might introduce an issue
-- where removing a link (perhaps accidentally) from QGIS layer and recreating it will assign a
-- different `fid` value for the original link. This can cause problems when updating more recent
-- revisions of infrastructure links to JORE4.
-- 
-- By adding 1_000_000_000 (one US billion) to `internal_id` value it is tried to keep ID spaces for
-- (1) Digiroad-originated and (2) HSL-custom links apart from each other. Currently, `internal_id`
-- is used e.g. as the internal primary key in JORE4 map-matching service.
-- 
UPDATE :schema.fix_layer_link
SET link_id     = 'hsl_' || fid,
    internal_id =  1000000000 + fid;

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

-- Add data integrity constraints for exclusion geometries.
ALTER TABLE :schema.fix_layer_link_exclusion

    ALTER COLUMN link_id SET NOT NULL,
    ALTER COLUMN geometry_fid SET NOT NULL,

    ADD CONSTRAINT fix_layer_link_exclusion_pkey PRIMARY KEY (link_id, geometry_fid),
    ADD CONSTRAINT fk_fix_layer_link_exclusion_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_linkki (link_id),
    ADD CONSTRAINT fk_fix_layer_link_exclusion_geometry_fid FOREIGN KEY (geometry_fid) REFERENCES :schema.fix_layer_link_exclusion_geometry (fid);

-- 
-- Create SQL view for infrastructure links intended to be used (when exporting data) instead of
-- tables imported from shapefiles.
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

-- 
-- Determine and compute additional fields for public transport stop points.
-- 

ALTER TABLE digiroad.fix_layer_stop_point
    ADD COLUMN link_id text,
    ADD COLUMN internal_id int,
    ADD COLUMN vaik_suunt int,
    ADD COLUMN sijainti_m double precision,
    ADD COLUMN kuntakoodi int;

-- `internal_id` is for SQL view in order to distinguish custom HSL-defined stop
-- points from ones defined in Digiroad. ID value will be derived from the
-- primary key of GeoPackage layer (`fid`). A separate ID value space is forced
-- by adding 1_000_000_000.
UPDATE :schema.fix_layer_stop_point SET internal_id =  1000000000 + fid;
ALTER TABLE :schema.fix_layer_stop_point ALTER COLUMN internal_id SET NOT NULL;

-- Resolve `link_id` and `kuntakoodi` attribute values.
-- `link_id` is resolved as being the ID of the closest infrastructure link
-- (either from Digiroad or fix layer). In case of one-way streets, a stop point
-- must reside on the right-hand side with regard to the direction of traffic
-- flow on the link.
UPDATE :schema.fix_layer_stop_point AS s
SET (link_id, kuntakoodi) = (
    SELECT l.link_id, l.kuntakoodi
    FROM :schema.dr_linkki_fixup l
    WHERE
        ST_DWithin(l.geom, s.geom, 50.0)
        AND (
                -- bidirectional
                l.ajosuunta = 2
            OR
                -- in the direction of LINESTRING
                l.ajosuunta = 4
                AND ST_Contains(ST_Buffer(ST_Force2D(l.geom), 50.0, 'side=right'), s.geom)
            OR
                -- against the direction of LINESTRING
                l.ajosuunta = 3
                AND ST_Contains(ST_Buffer(ST_Force2D(l.geom), 50.0, 'side=left'), s.geom)
        )
    ORDER BY l.geom <-> s.geom ASC
    LIMIT 1
);

-- Resolve `vaik_suunt` and `sijainti_m` attribute values.
UPDATE :schema.fix_layer_stop_point AS s
SET (vaik_suunt, sijainti_m) = (
    SELECT
        -- reusing Digiroad code values with regard to directionality of stop
        CASE
            WHEN ST_Contains(ST_Buffer(ST_Force2D(l.geom), 50.0, 'side=right'), s.geom) THEN 2
            WHEN ST_Contains(ST_Buffer(ST_Force2D(l.geom), 50.0, 'side=left'), s.geom) THEN 3
            ELSE NULL
        END AS vaik_suunt,
        -- First, resolve the fraction (0..1), then multiply it by the length of the link.
        ST_LineLocatePoint(ST_Force2D(l.geom), s.geom) * ST_3DLength(l.geom) AS sijainti_m
    FROM :schema.dr_linkki_fixup l
    WHERE l.link_id = s.link_id
);

-- 
-- Create SQL view for public transport stop points intended to be used (when exporting data)
-- instead of tables imported from shapefiles.
-- 

CREATE VIEW :schema.dr_pysakki_fixup AS
SELECT
    p.id,
    valtak_id,
    matk_tunn,
    p.link_id,
    vaik_suunt,
    sijainti_m,
    p.kuntakoodi,
    nimi_su,
    nimi_ru,
    'digiroad_r'::text AS hsl_infra_source,
    p.geom
FROM :schema.dr_pysakki p
INNER JOIN :schema.dr_linkki_fixup l ON l.link_id = p.link_id
WHERE
    -- Filter out stop overridden by fix layer.
    valtak_id NOT IN (
        SELECT valtak_id
        FROM :schema.fix_layer_stop_point
    )
UNION
SELECT
    internal_id AS id,
    valtak_id,
    matk_tunn,
    s.link_id,
    vaik_suunt,
    sijainti_m,
    s.kuntakoodi,
    nimi_su,
    nimi_ru,
    'hsl_fixup'::text AS hsl_infra_source,
    s.geom
FROM :schema.fix_layer_stop_point s
INNER JOIN :schema.dr_linkki_fixup l ON l.link_id = s.link_id
WHERE
    -- Filter out possibly invalid rows.
    vaik_suunt IN (2, 3)
    AND sijainti_m IS NOT NULL
    AND NOT EXISTS (
        -- sanity check to guarantee non-overlapping IDs between two queries combined with UNION
        -- operator
        SELECT 1
        FROM :schema.dr_pysakki p
        WHERE p.id = s.internal_id
    );
