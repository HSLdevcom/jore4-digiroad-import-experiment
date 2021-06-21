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
        closest_dr_stop.stop_gid,
        closest_dr_stop.dist,
        link.gid AS link_gid,
        link.link_id
    FROM route_endpoints rep, match_params p
    CROSS JOIN LATERAL (
        SELECT
            dr_stop.gid AS stop_gid, 
            rep.geom <-> dr_stop.geom AS dist
        FROM routing.dr_pysakki dr_stop
        WHERE ST_DWithin(rep.geom, dr_stop.geom, p.route_endpoint_search_radius)
        ORDER BY rep.geom <-> dr_stop.geom
        LIMIT 1
    ) AS closest_dr_stop
    INNER JOIN routing.dr_pysakki stop ON stop.gid = closest_dr_stop.stop_gid
    INNER JOIN routing.dr_linkki link USING (link_id)
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
via_point_closest_vertices AS (
    -- Find closest vertex for each via point.
    SELECT
        vp.path,
        closest_vertex.vertex_id,
        closest_vertex.dist
    FROM ordered_via_point_set vp, match_params p
    CROSS JOIN LATERAL (
        SELECT
            vert.id AS vertex_id, 
            vp.geom <-> vert.the_geom AS dist
        FROM routing.dr_linkki_vertices_pgr vert
        WHERE ST_DWithin(vp.geom, vert.the_geom, p.via_point_search_radius)
        ORDER BY vp.geom <-> vert.the_geom
        LIMIT 1
    ) AS closest_vertex
    INNER JOIN routing.dr_linkki_vertices_pgr vert ON vert.id = closest_vertex.vertex_id
    ORDER BY vp.path
),
via_vertices AS (
    -- XXX: Note the array cast (int vs bigint). Beware!
    SELECT array_agg(vertex_id)::int[] AS id_arr FROM via_point_closest_vertices
),
edge_query AS (
    -- Construct edge query for pgr_dijkstra function.
    SELECT query.txt
    FROM (
        SELECT array_to_string(array_agg(link_gid), ',') AS txt
        FROM route_terminal_info
    ) terminal_link_gids, match_params p
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
    FROM edge_query query, via_vertices via
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
        FROM pgr_dijkstraVia(
            query.txt,
            ARRAY[start_vertices.vertex_id] || via.id_arr || ARRAY[end_vertices.vertex_id],
            true, -- directed
            strict:=true,
            U_turn_on_edge:=true
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
    -- Select the longest path alternative.
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
-- SELECT * FROM via_vertices;
-- SELECT * FROM edge_query;
-- SELECT * FROM shortest_path_result;
SELECT ST_AsGeoJSON(ST_Transform(geom, 4326)) AS geojson FROM compound_line;
