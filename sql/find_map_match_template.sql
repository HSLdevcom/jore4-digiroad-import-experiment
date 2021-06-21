-- Algorithm description:
-- (1) Transform original linestring coordinates from EPSG:4326 (WGS84) to EPSG:3067.
-- (2) Find the closest bus stops at both ends of the linestring.
-- (3) Resolve terminal links from both ends of the linestring by following the association from the bus stops
-- (4) Prepare an SQL query that limits the links to be considered by pgRouting with buffering approach where the
--     linestring given as parameter will be expanded to a polygon (with defined radius in meters). The target links
--     are required to be contained inside that polygon.
-- (5) For both terminal links at ends of the compound linestring, resolve two junction nodes (source and target)
--     for each terminal link and yield four different route alternatives (by the possible node combinations) of which
--     the one that contains both terminal links as a whole is selected.

WITH jore3_route AS (
    -- Insert your coordinates here in EWKT format.
    SELECT ST_GeomFromEWKT('SRID=4326;LINESTRING(...)') AS geom
),
params AS (
    SELECT
        -- Jore3 route endpoint must reside within given radius (in meters) from some Digiroad stop.
        25 AS end_point_search_radius,
        -- The radius (in meters) used to expand Jore route to find and constrain suitable Digiroad links.
        25 AS route_expand_radius
),
jore3_route_3067 AS (
    SELECT ST_Transform(geom, 3067) AS geom FROM jore3_route
),
route_endpoints AS (
    SELECT 'start' AS endpoint_type, ST_Transform(ST_StartPoint(geom), 3067) AS geom FROM jore3_route_3067
    UNION
    SELECT 'end', ST_Transform(ST_EndPoint(geom), 3067) FROM jore3_route_3067
),
route_terminal_info AS (
    -- Find terminal links on both route endpoints by first resolving closest Digiroad stop and then get links.
    SELECT
        rep.endpoint_type,
        closest_dr_stop.stop_gid,
        closest_dr_stop.dist,
        link.gid AS link_gid,
        link.link_id
    FROM route_endpoints rep, params p
    CROSS JOIN LATERAL (
        SELECT
            dr_stop.gid AS stop_gid,
            rep.geom <-> dr_stop.geom AS dist
        FROM routing.dr_pysakki dr_stop
        WHERE ST_DWithin(rep.geom, dr_stop.geom, p.end_point_search_radius)
        ORDER BY rep.geom <-> dr_stop.geom
        LIMIT 1
    ) AS closest_dr_stop
    INNER JOIN routing.dr_pysakki stop ON stop.gid = closest_dr_stop.stop_gid
    INNER JOIN routing.dr_linkki link USING (link_id)
),
edge_query AS (
    -- Construct edge query for pgr_dijkstra function.
    SELECT query.txt
    FROM (
        SELECT array_to_string(array_agg(link_gid), ',') AS txt
        FROM route_terminal_info
    ) terminal_link_gids, params p
    CROSS JOIN LATERAL (
        -- Filtering edges in WHERE clause.
        SELECT 'SELECT gid AS id, source, target, cost, reverse_cost'
            || ' FROM routing.dr_linkki'
            || ' WHERE gid IN (' || terminal_link_gids.txt || ')'
            || ' OR ST_Contains(ST_Buffer(ST_Transform(ST_GeomFromEWKT(''' || ST_AsEWKT(geom) || '''), 3067), ' || p.route_expand_radius || '), geom)' AS txt
        FROM jore3_route
    ) query
),
shortest_path_alternatives AS (
    SELECT paths.*
    FROM edge_query query
    CROSS JOIN (
        -- Produce 2 start points for both endpoints of the first link.
        SELECT source AS vertex_id
        FROM route_terminal_info rti
        INNER JOIN routing.dr_linkki l ON l.gid = rti.link_gid
        WHERE rti.endpoint_type = 'start'
        UNION
        SELECT target
        FROM route_terminal_info rti
        INNER JOIN routing.dr_linkki l ON l.gid = rti.link_gid
        WHERE rti.endpoint_type = 'start'
    ) AS start_vertices
    CROSS JOIN (
        -- Produce 2 end points for both endpoints of the last link.
        SELECT source AS vertex_id
        FROM route_terminal_info rti
        INNER JOIN routing.dr_linkki l ON l.gid = rti.link_gid
        WHERE rti.endpoint_type = 'end'
        UNION
        SELECT target
        FROM route_terminal_info rti
        INNER JOIN routing.dr_linkki l ON l.gid = rti.link_gid
        WHERE rti.endpoint_type = 'end'
    ) AS end_vertices
    CROSS JOIN LATERAL (
        -- Produce 4 path alternatives by 4 permutations on 2 different endpoints on both ends of the route.
        SELECT
            start_vertices.vertex_id AS start_vertex,
            end_vertices.vertex_id AS end_vertex,
            seq,
            path_seq,
            node,
            edge,
            pt.cost,
            agg_cost,
            ST_AsText(geom) AS geom
        FROM pgr_dijkstra(
            query.txt,
            start_vertices.vertex_id,
            end_vertices.vertex_id,
            TRUE -- directed
        ) AS pt
        INNER JOIN routing.dr_linkki link ON pt.edge = link.gid
    ) AS paths
),
shortest_path_link_counts AS (
    SELECT start_vertex, end_vertex, count(seq) AS link_count
    FROM shortest_path_alternatives
    GROUP BY start_vertex, end_vertex
),
shortest_path_result AS (
    -- Select the longest path alternative (containing both the start link and the end link).
    SELECT spa.seq, spa.path_seq, spa.node, spa.edge, spa.cost, spa.agg_cost, spa.geom
    FROM (
        SELECT start_vertex, end_vertex
        FROM shortest_path_link_counts
        ORDER BY link_count DESC
        LIMIT 1
    ) t
    INNER JOIN shortest_path_alternatives spa ON spa.start_vertex = t.start_vertex AND spa.end_vertex = t.end_vertex
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
