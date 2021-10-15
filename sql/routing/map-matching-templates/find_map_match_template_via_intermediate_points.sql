-- Algorithm description:
-- (1) Transform original linestring coordinates from EPSG:4326 (WGS84) to EPSG:3067.
-- (2) Transform the via point coordinates given as parameter from EPSG:4326 to EPSG:3067
-- (3) Find the closest bus stops on both ends of the linestring.
-- (4) Resolve terminal links from the both ends of the linestring by following the association from the resolved
--     bus stops.
-- (5) Prepare an SQL query that limits the links to be considered by pgRouting with buffering approach where the
--     linestring given as parameter will be expanded to a polygon (with defined radius in meters). The target links
--     are required to be contained inside that polygon.
-- (6) For both terminal links at ends of the compound linestring, resolve two junction nodes (source and target)
--     for each terminal link and yield four different route alternatives (by the possible node combinations) of which
--     the one that contains both terminal links as a whole is selected. The via point coordinates are inserted
--     in between the possible source and target nodes.

WITH jore3_route AS (
    -- Insert your coordinates here in EWKT format.
    SELECT ST_GeomFromEWKT('SRID=4326;LINESTRING(...)') AS geom
),
via_points AS (
    -- Predefined points through which the matched route must pass. These are mapped to nearest topology vertices while finding path.
    -- Insert your coordinates into geometry array in EWKT format.
    SELECT ARRAY[
        ST_GeomFromEWKT('SRID=4326;POINT(...)'),
        ST_GeomFromEWKT('SRID=4326;POINT(...)'),
        ...
    ]::geometry[] AS geom_arr
),
match_params AS (
    -- The parameters may be tuned in order to have working map matching results.
    SELECT
        -- Digiroad stops on both ends of Jore3 route are searched within this given radius (in meters).
        25 AS route_endpoint_search_radius,
        -- Digiroad link endpoints (vertices in topology) are searched for each via point within this given radius (in meters).
        25 AS via_point_search_radius,
        -- The radius (in meters) used to expand Jore3 route to filter applicable Digiroad links.
        50 AS route_expand_radius
),
jore3_route_3067 AS (
    SELECT ST_Transform(geom, 3067) AS geom FROM jore3_route
),
route_endpoints AS (
    SELECT 'start' AS endpoint_type, ST_StartPoint(geom) AS geom FROM jore3_route_3067
    UNION
    SELECT 'end', ST_EndPoint(geom) FROM jore3_route_3067
),
route_terminal_info AS (
    -- Find terminal links on both route endpoints by first resolving closest Digiroad stop and then get links.
    SELECT
        rep.endpoint_type,
        closest_stop.public_transport_stop_id,
        closest_stop.dist,
        l.infrastructure_link_id
    FROM route_endpoints rep, match_params p
    CROSS JOIN LATERAL (
        SELECT s.public_transport_stop_id, rep.geom <-> s.geom AS dist
        FROM routing.public_transport_stop s
        WHERE ST_DWithin(rep.geom, s.geom, p.route_endpoint_search_radius)
        ORDER BY dist
        LIMIT 1
    ) AS closest_stop
    INNER JOIN routing.public_transport_stop s USING (public_transport_stop_id)
    INNER JOIN routing.infrastructure_link l ON l.infrastructure_link_id = s.located_on_infrastructure_link_id
),
ordered_via_point_set AS (
    SELECT (dp).path, (dp).geom
    FROM (
        SELECT ST_Dump(ST_Transform(ST_Collect(geom_arr), 3067)) AS dp
        FROM (
            -- Filter out empty via point array.
            SELECT geom_arr FROM via_points WHERE cardinality(geom_arr) > 0
        ) y
    ) x
    ORDER BY path
),
via_point_closest_nodes AS (
    -- Find closest node for each via point.
    SELECT vp.path, closest_node.node_id, closest_node.dist
    FROM ordered_via_point_set vp, match_params p
    CROSS JOIN LATERAL (
        SELECT node.id AS node_id, vp.geom <-> node.the_geom AS dist
        FROM routing.infrastructure_link_vertices_pgr node
        WHERE ST_DWithin(vp.geom, node.the_geom, p.via_point_search_radius)
        ORDER BY dist
        LIMIT 1
    ) AS closest_node
    INNER JOIN routing.infrastructure_link_vertices_pgr node ON node.id = closest_node.node_id
    ORDER BY vp.path
),
via_nodes AS (
    SELECT array_agg(node_id)::bigint[] AS id_arr FROM via_point_closest_nodes
),
edge_query AS (
    -- Construct edge query for pgr_dijkstra function.
    SELECT query.txt
    FROM (
        SELECT array_to_string(array_agg(infrastructure_link_id), ',') AS txt
        FROM route_terminal_info
    ) terminal_link_ids, match_params p
    CROSS JOIN LATERAL (
        -- Filtering edges in WHERE clause.
        SELECT 'SELECT infrastructure_link_id AS id, start_node_id AS source, end_node_id AS target, cost, reverse_cost'
            || ' FROM routing.infrastructure_link'
            || ' WHERE infrastructure_link_id IN (' || terminal_link_ids.txt || ')'
            || ' OR ST_Contains(ST_Buffer(ST_Transform(ST_GeomFromEWKT(''' || ST_AsEWKT(geom) || '''), 3067), ' || p.route_expand_radius || '), geom)' AS txt
        FROM jore3_route
    ) query
),
shortest_path_alternatives AS (
    SELECT paths.*
    FROM edge_query query, via_nodes via
    CROSS JOIN (
        -- Produce 2 start points for both endpoints of the first link.
        SELECT start_node_id AS node_id
        FROM route_terminal_info rti
        INNER JOIN routing.infrastructure_link l USING (infrastructure_link_id)
        WHERE rti.endpoint_type = 'start'
        UNION
        SELECT end_node_id
        FROM route_terminal_info rti
        INNER JOIN routing.infrastructure_link l USING (infrastructure_link_id)
        WHERE rti.endpoint_type = 'start'
    ) AS start_nodes
    CROSS JOIN (
        -- Produce 2 end points for both endpoints of the last link.
        SELECT start_node_id AS node_id
        FROM route_terminal_info rti
        INNER JOIN routing.infrastructure_link l USING (infrastructure_link_id)
        WHERE rti.endpoint_type = 'end'
        UNION
        SELECT end_node_id
        FROM route_terminal_info rti
        INNER JOIN routing.infrastructure_link l USING (infrastructure_link_id)
        WHERE rti.endpoint_type = 'end'
    ) AS end_nodes
    CROSS JOIN LATERAL (
        -- Produce 4 path alternatives by 4 permutations on 2 different endpoints on both ends of the route.
        SELECT
            start_nodes.node_id AS start_node_id,
            end_nodes.node_id AS end_node_id,
            seq,
            path_seq,
            node,
            edge,
            pt.cost,
            agg_cost,
            ST_AsText(geom) AS geom
        FROM pgr_dijkstraVia(
            query.txt,
            ARRAY[start_nodes.node_id] || via.id_arr || ARRAY[end_nodes.node_id],
            true, -- directed
            strict:=true,
            U_turn_on_edge:=true
        ) AS pt
        INNER JOIN routing.infrastructure_link l ON pt.edge = l.infrastructure_link_id
    ) AS paths
),
shortest_path_link_counts AS (
    SELECT start_node_id, end_node_id, count(seq) AS link_count
    FROM shortest_path_alternatives
    GROUP BY start_node_id, end_node_id
),
shortest_path_result AS (
    -- Select the longest path alternative.
    SELECT spa.seq, spa.path_seq, spa.node, spa.edge, spa.cost, spa.agg_cost, spa.geom
    FROM (
        SELECT start_node_id, end_node_id
        FROM shortest_path_link_counts
        ORDER BY link_count DESC
        LIMIT 1
    ) t
    INNER JOIN shortest_path_alternatives spa ON spa.start_node_id = t.start_node_id AND spa.end_node_id = t.end_node_id
    ORDER BY seq
),
compound_line AS (
    SELECT ST_LineMerge(ST_Collect(ST_SetSRID(geom, 3067))) AS geom
    FROM shortest_path_result
)
-- SELECT * FROM route_terminal_info;
-- SELECT * FROM via_nodes;
-- SELECT * FROM edge_query;
-- SELECT * FROM shortest_path_result;
SELECT ST_AsGeoJSON(ST_Transform(geom, 4326)) AS geojson FROM compound_line;
