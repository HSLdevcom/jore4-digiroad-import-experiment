WITH jore3_route AS (
    -- This route geometry data is copyright © by 2021 Helsingin seudun liikenne (HSL) and licensed under a Creative Commons Attribution 4.0 International License (https://creativecommons.org/licenses/by/4.0/).
    SELECT ST_GeomFromEWKT('SRID=4326;LINESTRING(24.974312236 60.167351409,24.974076253 60.167290311,24.97200727 60.166766932,24.971698464 60.166679435,24.971517313 60.166644858,24.970881699 60.166469993,24.970355203 60.16633023,24.969918228 60.166171858,24.969736817 60.166128305,24.969537926 60.166102832,24.969357837 60.166104148,24.968800882 60.1661531,24.96863933 60.166172232,24.968100382 60.166221049,24.967758475 60.166232522,24.966659665 60.166231562,24.966585784 60.166169268,24.965462011 60.166545475,24.962590351 60.167517817,24.962162315 60.167664541,24.961831583 60.16744254,24.961482585 60.167211694,24.960055169 60.167679816,24.958359913 60.168230644,24.957681534 60.168441995,24.958233857 60.168850903,24.958335144 60.169236141,24.958472454 60.169621118,24.958655961 60.16973648,24.959160528 60.169741807,24.959540327 60.169792915,24.960224848 60.171026654,24.961508962 60.173665283,24.96136643 60.173720172,24.961242173 60.173783905,24.961190755 60.173874039,24.961157611 60.173973015,24.961113006 60.174296476,24.960211288 60.174267105,24.959760691 60.174261391,24.958174205 60.174227984,24.956605474 60.174185454,24.956262959 60.174178949,24.953071211 60.17408524,24.952043931 60.174074667,24.951719691 60.174076995,24.950403939 60.174059504,24.95040679 60.17415822,24.950354305 60.174212452,24.95021227 60.174285278,24.950068421 60.174295285,24.949923278 60.174260421,24.949777616 60.174207608,24.949666946 60.17411864,24.949609281 60.173993389,24.949607209 60.173921595,24.949568076 60.173814163,24.949235038 60.173511363,24.949179187 60.17344893,24.949123854 60.173404446,24.948883217 60.173181768,24.948789789 60.173065748,24.948695845 60.17293178,24.94845599 60.172736023,24.947938455 60.172281946,24.947864855 60.172228616,24.947791255 60.172175286,24.947627852 60.172131574,24.947410929 60.172106196,24.94697786 60.172082361,24.945193098 60.17204124,24.945048742 60.172033293,24.944903871 60.172007397,24.944830791 60.171972014,24.944878624 60.171127926,24.944907949 60.17089434,24.945170393 60.170623189,24.944791636 60.170607936,24.94459145 60.170537554,24.944392037 60.170494095,24.944175127 60.170468712,24.943904699 60.170461661,24.942733186 60.170443068,24.940263316 60.170379821,24.940065191 60.170381226,24.939920843 60.170373273,24.939867065 60.170382631,24.939630868 60.170312497,24.939448706 60.170241979,24.938483616 60.169880797,24.938147799 60.170107574,24.937882233 60.170271021,24.937086541 60.170797256,24.938477529 60.170931034)') AS geom
),
match_params AS (
    SELECT
        -- Digiroad stops on both ends of Jore3 route are searched within this given radius (in meters).
        35 AS route_endpoint_search_radius,
        -- The radius (in meters) used to expand Jore3 route to filter applicable Digiroad links.
        45 AS route_expand_radius
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

-- GeoJSON result:
--  {"type":"LineString","coordinates":[[24.939316517,60.170981403],[24.939221214,60.170989926],[24.938993874,60.170978378],[24.937495671,60.170871013],[24.937293082,60.170838506],[24.938593968,60.169977459],[24.93865564,60.170001574],[24.938811328,60.170055238],[24.939013503,60.170130831],[24.939605078,60.170352024],[24.939751784,60.170382778],[24.94003545,60.170458586],[24.942758522,60.170525926],[24.944055109,60.170543608],[24.944203777,60.170556307],[24.944427937,60.170585824],[24.944587242,60.170621313],[24.944756346,60.170676543],[24.944884071,60.170742853],[24.944919203,60.170868417],[24.944896741,60.17102307],[24.94485546,60.171349651],[24.944830232,60.171644649],[24.944812594,60.171808925],[24.944814393,60.171872464],[24.944918833,60.172001358],[24.945209919,60.172034103],[24.945474354,60.172047329],[24.947424699,60.172099247],[24.947710803,60.172149774],[24.94791299,60.172239285],[24.948542081,60.172803382],[24.948838976,60.173083696],[24.949094399,60.173380964],[24.949503712,60.173757291],[24.949595745,60.173842364],[24.949624678,60.173984987],[24.94962954,60.174069519],[24.949731817,60.174177699],[24.949859974,60.174238909],[24.949974663,60.174291736],[24.950153293,60.174311422],[24.950278105,60.174305107],[24.950433471,60.174207461],[24.950431496,60.174129503],[24.950379951,60.174021892],[24.953073646,60.174090539],[24.956281556,60.174177984],[24.958188683,60.17423098],[24.959768219,60.174264084],[24.961144936,60.174293044],[24.961462041,60.174307704],[24.961667623,60.174310929],[24.961784287,60.174312705],[24.961865993,60.174304873],[24.96184562,60.174211192],[24.961829576,60.174117202],[24.961758837,60.173973104],[24.961646438,60.173746899],[24.961130678,60.172732731],[24.960620396,60.171711244],[24.960501358,60.171478982],[24.960418063,60.171303504],[24.960293016,60.171038823],[24.960198764,60.170846758],[24.960082768,60.170604787],[24.959910606,60.170254896],[24.95979937,60.170020822],[24.959733686,60.169874833],[24.959667955,60.169771769],[24.959528142,60.169687485],[24.95937003,60.169671532],[24.959061688,60.169664843],[24.958902855,60.169661678],[24.958728664,60.169641659],[24.958595632,60.16958932],[24.958513536,60.169490628],[24.958513142,60.169373534],[24.958509574,60.169227981],[24.958509824,60.169060427],[24.958478185,60.168924538],[24.95839469,60.168845216],[24.958263473,60.168764863],[24.957965939,60.168577523],[24.957757981,60.168433706],[24.957869635,60.168412469],[24.958210502,60.168304433],[24.958280648,60.168281065],[24.958355336,60.168251319],[24.958649025,60.168147962],[24.959590677,60.167834178],[24.959908687,60.16771464],[24.960259106,60.167622968],[24.960483753,60.167549154],[24.961502038,60.167214612],[24.962174566,60.167667496],[24.96419673,60.166981064],[24.966589224,60.166173426],[24.96667809,60.166227864],[24.967674772,60.166238396],[24.96783709,60.166235946],[24.96824231,60.166205424],[24.968671747,60.166162151],[24.969092677,60.166127629],[24.969403348,60.166103945],[24.96957521,60.166113019],[24.969773602,60.16613643],[24.969966703,60.166180167],[24.970131143,60.166241481],[24.970298504,60.166302778],[24.970512571,60.166371023],[24.970817219,60.166454658],[24.971057138,60.166509709],[24.971314845,60.166577678],[24.971538484,60.16663837],[24.972685997,60.166936627],[24.97294111,60.167002927],[24.973105001,60.167045503],[24.974222735,60.1673252],[24.974505004,60.167395829],[24.974691128,60.167442425]]}
