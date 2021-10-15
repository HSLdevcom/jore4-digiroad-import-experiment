-- Algorithm description:
-- (1) Transform original linestring coordinates from EPSG:4326 (WGS84) to EPSG:3067.
-- (2) Find closest road links on both ends of the linestring.
-- (3) Prepare an SQL query that limits the links to be considered by pgRouting with buffering approach where the
--     linestring given as parameter will be expanded to a polygon (with defined radius in meters). The target links
--     are required to be contained inside that polygon.
-- (4) For both terminal links at ends of the compound linestring, resolve two junction nodes (source and target)
--     for each terminal link and yield four different route alternatives (by the possible node combinations) of which
--     the one that contains both terminal links as a whole is selected.

WITH jore3_route AS (
    -- Insert your coordinates here in EWKT format.
    SELECT ST_GeomFromEWKT('SRID=4326;LINESTRING(...)') AS geom
),
match_params AS (
    SELECT
        -- Digiroad links on both ends of Jore3 route are searched within this given radius (in meters).
        25 AS route_endpoint_search_radius,
        -- The radius (in meters) used to expand Jore3 route to filter applicable Digiroad links.
        25 AS route_expand_radius
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
    -- Find closest Digiroad links on both ends of the route.
    SELECT
        rep.endpoint_type,
        closest_link.dist,
        closest_link.infrastructure_link_id
    FROM route_endpoints rep, match_params p
    CROSS JOIN LATERAL (
        SELECT l.infrastructure_link_id, rep.geom <-> l.geom AS dist
        FROM routing.infrastructure_link l
        WHERE ST_DWithin(rep.geom, l.geom, p.route_endpoint_search_radius)
        ORDER BY dist
        LIMIT 1
    ) AS closest_link
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
    FROM edge_query query
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
        FROM pgr_dijkstra(
            query.txt,
            start_nodes.node_id,
            end_nodes.node_id,
            TRUE -- directed
        ) AS pt
        INNER JOIN routing.infrastructure_link link ON pt.edge = link.infrastructure_link_id
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
-- SELECT * FROM edge_query;
-- SELECT * FROM shortest_path_result;
SELECT ST_AsGeoJSON(ST_Transform(geom, 4326)) AS geojson FROM compound_line;
