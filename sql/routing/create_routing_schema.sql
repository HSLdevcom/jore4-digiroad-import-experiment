DROP SCHEMA IF EXISTS :schema CASCADE;

CREATE SCHEMA :schema;

--
-- Create table and populate data for direction of traffic flow enumeration
--

-- Valid `ajosuunta` codes in Digiroad are:
--  `2` ~ bidirectional
--  `3` ~ against digitised direction
--  `4` ~ along digitised direction
CREATE TABLE :schema.traffic_flow_direction (
    traffic_flow_direction_type int PRIMARY KEY,
    traffic_flow_direction_name text NOT NULL,
    description text NOT NULL
);
COMMENT ON TABLE :schema.traffic_flow_direction IS
    'The possible directions of traffic flow on infrastructure links. Using code values from Digiroad codeset.';
COMMENT ON COLUMN :schema.traffic_flow_direction.traffic_flow_direction_type IS
    'Numeric enum value for direction of traffic flow. The code value originates from Digiroad codeset.';
COMMENT ON COLUMN :schema.traffic_flow_direction.traffic_flow_direction_name IS
    'The short name for direction of traffic flow. The text value originates from the JORE4 database schema.';
INSERT INTO :schema.traffic_flow_direction (traffic_flow_direction_type, traffic_flow_direction_name, description) VALUES
    (2, 'bidirectional', 'Bidirectional'),
    (3, 'backward', 'Against digitised direction'),
    (4, 'forward', 'Along digitised direction');

--
-- Create table and populate data for infrastructure element sources
--

CREATE TABLE :schema.infrastructure_source (
    infrastructure_source_id int PRIMARY KEY,
    infrastructure_source_name text NOT NULL,
    description text NOT NULL
);
COMMENT ON TABLE :schema.infrastructure_source IS
    'The enumerated sources for infrastructure network entities';
COMMENT ON COLUMN :schema.infrastructure_source.infrastructure_source_id IS
    'The numeric enum value for the infrastructure element source. This enum code is only local to this routing schema. ATM, it is not intended to be distributed to or shared across other JORE4 services.';
COMMENT ON COLUMN :schema.infrastructure_source.infrastructure_source_name IS
    'The short name for the infrastructure element source';
INSERT INTO :schema.infrastructure_source (infrastructure_source_id, infrastructure_source_name, description) VALUES
    (1, 'digiroad_r', 'Digiroad R export made available by Finnish Transport Infrastructure Agency (https://vayla.fi)');
INSERT INTO :schema.infrastructure_source (infrastructure_source_id, infrastructure_source_name, description) VALUES
    (2, 'hsl_fixup', 'HSL additions on top of Digiroad infrastructure network');

--
-- Import infrastructure links
--

CREATE TABLE :schema.infrastructure_link AS
SELECT
    src.id::bigint AS infrastructure_link_id,
    isrc.infrastructure_source_id,
    src.link_id AS external_link_id,
    dir.traffic_flow_direction_type,
    src.kuntakoodi AS municipality_code,
    src.linkkityyp AS external_link_type,
    src.link_tila AS external_link_state,
    json_build_object('fi', src.tienimi_su,
                      'sv', src.tienimi_ru
    )::jsonb AS name,
    ST_Force3D(src.geom) AS geom_3d
FROM :source_schema.dr_linkki_fixup src
-- Filter out links with possibly invalid direction of traffic flow.
INNER JOIN :schema.traffic_flow_direction dir ON dir.traffic_flow_direction_type = src.ajosuunta
INNER JOIN :schema.infrastructure_source isrc ON isrc.infrastructure_source_name = src.hsl_infra_source;

COMMENT ON TABLE :schema.infrastructure_link IS
    'The infrastructure links, e.g. road or rail elements: https://www.transmodel-cen.eu/model/index.htm?goto=2:1:1:1:453';
COMMENT ON COLUMN :schema.infrastructure_link.infrastructure_link_id IS
    'The local ID of the infrastructure link. The requirement of the ID being of integer type is imposed by pgRouting.';
COMMENT ON COLUMN :schema.infrastructure_link.infrastructure_source_id IS
    'The ID of the external source system providing the link data.';
COMMENT ON COLUMN :schema.infrastructure_link.external_link_id IS
    'The ID of the infrastructure link within the external source system providing the link data';
COMMENT ON COLUMN :schema.infrastructure_link.traffic_flow_direction_type IS
    'A numeric enum value for direction of traffic flow allowed on the infrastructure link';
COMMENT ON COLUMN :schema.infrastructure_link.municipality_code IS
    'The official code of municipality in which the link is located';
COMMENT ON COLUMN :schema.infrastructure_link.external_link_type IS
    'The link type code defined within the external source system providing the link data';
COMMENT ON COLUMN :schema.infrastructure_link.external_link_state IS
    'The link state code defined within the external source system providing the link data';
COMMENT ON COLUMN :schema.infrastructure_link.name IS
    'JSON object containing name of road or street in different localisations';

-- Add data integrity constraints to `infrastructure_link` table after transformation from the source schema.
ALTER TABLE :schema.infrastructure_link
    ALTER COLUMN external_link_id SET NOT NULL,
    ALTER COLUMN infrastructure_source_id SET NOT NULL,
    ALTER COLUMN traffic_flow_direction_type SET NOT NULL,

    ADD CONSTRAINT infrastructure_link_pkey PRIMARY KEY (infrastructure_link_id),
    ADD CONSTRAINT uk_infrastructure_link_external_ref UNIQUE (infrastructure_source_id, external_link_id),
    ADD CONSTRAINT infrastructure_link_traffic_flow_direction_fkey FOREIGN KEY (traffic_flow_direction_type)
        REFERENCES :schema.traffic_flow_direction (traffic_flow_direction_type),
    ADD CONSTRAINT infrastructure_link_infrastructure_source_fkey FOREIGN KEY (infrastructure_source_id)
        REFERENCES :schema.infrastructure_source (infrastructure_source_id);

--
-- Create table and populate data for vehicle modes and types
--

CREATE TABLE :schema.vehicle_mode (
    vehicle_mode text PRIMARY KEY
);
COMMENT ON TABLE :schema.vehicle_mode IS
    'The vehicle modes from Transmodel: https://www.transmodel-cen.eu/model/index.htm?goto=1:6:1:283';
COMMENT ON COLUMN :schema.vehicle_mode.vehicle_mode IS
    'The vehicle mode from Transmodel: https://www.transmodel-cen.eu/model/index.htm?goto=1:6:1:283';
INSERT INTO :schema.vehicle_mode (vehicle_mode) VALUES
    ('bus'),
    ('tram'),
    ('train'),
    ('metro'),
    ('ferry');

CREATE TABLE :schema.vehicle_type (
    vehicle_type text PRIMARY KEY,
    belonging_to_vehicle_mode text NOT NULL REFERENCES :schema.vehicle_mode (vehicle_mode)
);
COMMENT ON TABLE :schema.vehicle_type IS
    'The vehicle types from Transmodel: https://www.transmodel-cen.eu/model/index.htm?goto=1:6:9:360';
COMMENT ON COLUMN :schema.vehicle_type.vehicle_type IS
    'The vehicle type from Transmodel: https://www.transmodel-cen.eu/model/index.htm?goto=1:6:9:360';
COMMENT ON COLUMN :schema.vehicle_type.belonging_to_vehicle_mode IS
    'The vehicle mode the vehicle type belongs to: https://www.transmodel-cen.eu/model/index.htm?goto=1:6:1:283';
INSERT INTO :schema.vehicle_type (vehicle_type, belonging_to_vehicle_mode) VALUES
    ('generic_bus', 'bus'),
    ('generic_tram', 'tram'),
    ('generic_train', 'train'),
    ('generic_metro', 'metro'),
    ('generic_ferry', 'ferry'),
    ('tall_electric_bus', 'bus');
CREATE INDEX ON :schema.vehicle_type (belonging_to_vehicle_mode);

--
-- Create an association table and populate data for which infrastructure links can be safely traversed
-- by which vehicle type
--

CREATE TABLE :schema.infrastructure_link_safely_traversed_by_vehicle_type (
    infrastructure_link_id bigint REFERENCES :schema.infrastructure_link (infrastructure_link_id),
    vehicle_type text REFERENCES :schema.vehicle_type (vehicle_type),
    PRIMARY KEY (infrastructure_link_id, vehicle_type)
);
COMMENT ON TABLE :schema.infrastructure_link_safely_traversed_by_vehicle_type IS
    'Which infrastructure links are safely traversed by which vehicle types?';
COMMENT ON COLUMN :schema.infrastructure_link_safely_traversed_by_vehicle_type.infrastructure_link_id IS
    'The infrastructure link that can be safely traversed by the vehicle type';
COMMENT ON COLUMN :schema.infrastructure_link_safely_traversed_by_vehicle_type.vehicle_type IS
    'The vehicle type that can safely traverse the infrastructure link';

CREATE INDEX ON :schema.infrastructure_link_safely_traversed_by_vehicle_type (vehicle_type, infrastructure_link_id);

INSERT INTO :schema.infrastructure_link_safely_traversed_by_vehicle_type (infrastructure_link_id, vehicle_type)
    SELECT lnk.infrastructure_link_id, 'generic_bus'
    FROM :schema.infrastructure_link lnk
    INNER JOIN :source_schema.dr_linkki_fixup src_lnk ON src_lnk.id = lnk.infrastructure_link_id::int
    WHERE src_lnk.is_generic_bus = true
UNION
    SELECT lnk.infrastructure_link_id, 'tall_electric_bus'
    FROM :schema.infrastructure_link lnk
    INNER JOIN :source_schema.dr_linkki_fixup src_lnk ON src_lnk.id = lnk.infrastructure_link_id::int
    WHERE src_lnk.is_tall_electric_bus = true
UNION
    SELECT lnk.infrastructure_link_id, 'generic_tram'
    FROM :schema.infrastructure_link lnk
    INNER JOIN :source_schema.dr_linkki_fixup src_lnk ON src_lnk.id = lnk.infrastructure_link_id::int
    WHERE src_lnk.is_tram = true
UNION
    SELECT lnk.infrastructure_link_id, 'generic_train'
    FROM :schema.infrastructure_link lnk
    INNER JOIN :source_schema.dr_linkki_fixup src_lnk ON src_lnk.id = lnk.infrastructure_link_id::int
    WHERE src_lnk.is_train = true
UNION
    SELECT lnk.infrastructure_link_id, 'generic_metro'
    FROM :schema.infrastructure_link lnk
    INNER JOIN :source_schema.dr_linkki_fixup src_lnk ON src_lnk.id = lnk.infrastructure_link_id::int
    WHERE src_lnk.is_metro = true
UNION
    SELECT lnk.infrastructure_link_id, 'generic_ferry'
    FROM :schema.infrastructure_link lnk
    INNER JOIN :source_schema.dr_linkki_fixup src_lnk ON src_lnk.id = lnk.infrastructure_link_id::int
    WHERE src_lnk.is_ferry = true;

--
-- Create network topology for infrastructure links
--

-- Add columns required by pgRouting extension.
SELECT AddGeometryColumn(:'schema', 'infrastructure_link', 'geom', 3067, 'LINESTRING', 2);
ALTER TABLE :schema.infrastructure_link ADD COLUMN start_node_id BIGINT,
                                        ADD COLUMN end_node_id BIGINT,
                                        ADD COLUMN cost FLOAT,
                                        ADD COLUMN reverse_cost FLOAT;

COMMENT ON COLUMN :schema.infrastructure_link.geom IS
    'The 2D linestring geometry describing the shape of the infrastructure link. The requirement of two-dimensionality and metric unit is imposed by pgRouting. The EPSG:3067 coordinate system applied is the same as is used in Digiroad.';
COMMENT ON COLUMN :schema.infrastructure_link.start_node_id IS
    'The ID of the start node for the infrastructure link based on its linestring geometry. The node points are resolved and generated by calling `pgr_createTopology` function of pgRouting.';
COMMENT ON COLUMN :schema.infrastructure_link.end_node_id IS
    'The ID of the end node for the infrastructure link based on its linestring geometry. The node points are resolved and generated by calling `pgr_createTopology` function of pgRouting.';
COMMENT ON COLUMN :schema.infrastructure_link.cost IS
    'The weight in terms of graph traversal for forward direction of the linestring geometry of the infrastructure link. When negative, the forward direction of the link (edge) will not be part of the graph within the shortest path calculation.';
COMMENT ON COLUMN :schema.infrastructure_link.reverse_cost IS
    'The weight in terms of graph traversal for reverse direction of the linestring geometry of the infrastructure link. When negative, the reverse direction of the link (edge) will not be part of the graph within the shortest path calculation.';

-- Create indices to improve performance of pgRouting.
CREATE INDEX infrastructure_link_geom_idx ON :schema.infrastructure_link USING GIST(geom);
CREATE INDEX infrastructure_link_start_node_idx ON :schema.infrastructure_link (start_node_id);
CREATE INDEX infrastructure_link_end_node_idx ON :schema.infrastructure_link (end_node_id);

-- Populate `geom` column before topology creation.
UPDATE :schema.infrastructure_link SET geom = ST_Force2D(geom_3d);

-- Create pgRouting topology.
SELECT pgr_createTopology(:'schema' || '.infrastructure_link', 0.001, 'geom', 'infrastructure_link_id', 'start_node_id', 'end_node_id');

COMMENT ON TABLE :schema.infrastructure_link_vertices_pgr IS
    'Topology nodes created for infrastructure links by pgRougting';

SELECT pgr_analyzeGraph(:'schema' || '.infrastructure_link', 0.001, 'geom', 'infrastructure_link_id', 'start_node_id', 'end_node_id');

-- Set up `cost` and `reverse_cost` parameters for pgRouting functions.
-- 
-- Negative `cost` effectively means pgRouting will not consider traversing the link along its digitised direction.
-- Correspondingly, negative `reverse_cost` means pgRouting will not consider traversing the link against its
-- digitised direction. Hence, with `cost` and `reverse_cost` we can (in addition to their main purpose) define
-- one-way directionality constraints for road links.
-- 
-- TODO: Do cost calculation based on speed limits.
UPDATE :schema.infrastructure_link SET
    cost = CASE WHEN traffic_flow_direction_type IN (2, 4) THEN ST_3DLength(geom_3d) ELSE -1 END,
    reverse_cost = CASE WHEN traffic_flow_direction_type IN (2, 3) THEN ST_3DLength(geom_3d) ELSE -1 END;

ALTER TABLE :schema.infrastructure_link ALTER COLUMN geom SET NOT NULL,
                                        ALTER COLUMN start_node_id SET NOT NULL,
                                        ALTER COLUMN end_node_id SET NOT NULL,
                                        ALTER COLUMN cost SET NOT NULL,
                                        ALTER COLUMN reverse_cost SET NOT NULL;

-- Add temporary column for the purpose of analysing one-way streets.
ALTER TABLE :schema.infrastructure_link ADD COLUMN pgr_dir TEXT;

UPDATE :schema.infrastructure_link SET
    pgr_dir = CASE WHEN (cost > 0 AND reverse_cost > 0) THEN 'B'   -- bidirectional
                   WHEN (cost > 0 AND reverse_cost < 0) THEN 'FT'  -- direction of the LINESSTRING
                   WHEN (cost < 0 AND reverse_cost > 0) THEN 'TF'  -- reverse direction of the LINESTRING
                   ELSE '' END;                                    -- unknown

ALTER TABLE :schema.infrastructure_link ALTER COLUMN pgr_dir SET NOT NULL;

-- Analyse one-way streets. A couple of columns in `infrastructure_link_vertices_pgr` table are
-- populated as side effect.
SELECT pgr_analyzeOneWay(:'schema' || '.infrastructure_link', ARRAY['', 'B', 'TF'], ARRAY['', 'B', 'FT'], ARRAY['', 'B', 'FT'], ARRAY['', 'B', 'TF'], oneway:='pgr_dir', source:='start_node_id', target:='end_node_id');

-- Drop temporary column used for analysing one-way streets.
ALTER TABLE :schema.infrastructure_link DROP COLUMN pgr_dir;

-- Drop 3D geometry since it cannot be utilised by pgRouting.
ALTER TABLE :schema.infrastructure_link DROP COLUMN geom_3d;

--
-- Import public transport stops
--

CREATE TABLE :schema.public_transport_stop AS
SELECT
    src.id::bigint AS public_transport_stop_id,
    src.valtak_id AS public_transport_stop_national_id,
    link.infrastructure_link_id AS located_on_infrastructure_link_id,
    isrc.infrastructure_source_id,
    CASE
        WHEN src.vaik_suunt = 2 THEN true
        WHEN src.vaik_suunt = 3 THEN false
        ELSE null
    END AS is_on_direction_of_link_forward_traversal,
    src.sijainti_m AS distance_from_link_start_in_meters,
    src.kuntakoodi AS municipality_code,
    json_build_object('fi', src.nimi_su,
                      'sv', src.nimi_ru
    )::jsonb AS name,
    src.geom
FROM :source_schema.dr_pysakki_fixup src
INNER JOIN :schema.infrastructure_link link ON link.external_link_id = src.link_id
INNER JOIN :schema.infrastructure_source isrc ON isrc.infrastructure_source_name = src.hsl_infra_source;

COMMENT ON TABLE :schema.public_transport_stop IS
    'The public transport stops imported from Digiroad export';
COMMENT ON COLUMN :schema.public_transport_stop.public_transport_stop_id IS
    'The local ID of the public transport stop';
COMMENT ON COLUMN :schema.public_transport_stop.public_transport_stop_national_id IS
    'The national (persistent) ID for the public transport stop';
COMMENT ON COLUMN :schema.public_transport_stop.located_on_infrastructure_link_id IS
    'The ID of the infrastructure link on which the stop is located';
COMMENT ON COLUMN :schema.public_transport_stop.infrastructure_source_id IS
    'The ID of the external source system providing the stop data';
COMMENT ON COLUMN :schema.public_transport_stop.is_on_direction_of_link_forward_traversal IS
    'Is the direction of traffic on this stop the same as the direction of the linestring describing the infrastructure link? If TRUE, the stop lies in the direction of the linestring. If FALSE, the stop lies in the reverse direction of the linestring. If NULL, the direction is undefined.';
COMMENT ON COLUMN :schema.public_transport_stop.distance_from_link_start_in_meters IS
    'The measure or M value of the stop from the start of the linestring (linear geometry) describing the infrastructure link. The SI unit is the meter.';
COMMENT ON COLUMN :schema.public_transport_stop.municipality_code IS
    'The official code of municipality in which the stop is located';
COMMENT ON COLUMN :schema.public_transport_stop.name IS
    'JSON object containing name in different localisations';
COMMENT ON COLUMN :schema.public_transport_stop.geom IS
    'The 2D point geometry describing the location of the public transport stop. The EPSG:3067 coordinate system applied is the same as is used in Digiroad.';

-- Add data integrity constraints to `public_transport_stop` table after transformation from the source schema.
ALTER TABLE :schema.public_transport_stop
    ALTER COLUMN located_on_infrastructure_link_id SET NOT NULL,
    ALTER COLUMN infrastructure_source_id SET NOT NULL,
    ALTER COLUMN distance_from_link_start_in_meters SET NOT NULL,
    ALTER COLUMN geom SET NOT NULL,

    ADD CONSTRAINT public_transport_stop_pkey PRIMARY KEY (public_transport_stop_id),
    ADD CONSTRAINT public_transport_stop_infrastructure_link_fkey FOREIGN KEY (located_on_infrastructure_link_id)
        REFERENCES :schema.infrastructure_link (infrastructure_link_id),
    ADD CONSTRAINT public_transport_stop_infrastructure_source_fkey FOREIGN KEY (infrastructure_source_id)
        REFERENCES :schema.infrastructure_source (infrastructure_source_id);

CREATE INDEX public_transport_stop_infrastructure_link_idx ON :schema.public_transport_stop (located_on_infrastructure_link_id);
CREATE INDEX public_transport_stop_geom_idx ON :schema.public_transport_stop USING GIST(geom);
