COPY (
    SELECT
        source.gid as external_stop_point_id,
        source.link_id as external_link_id,
        source.valtak_id as national_stop_point_id,
        CASE
            WHEN source.vaik_suunt = 2 THEN 'forward'
            WHEN source.vaik_suunt = 3 THEN 'backward'
        END AS direction_on_infra_link,
        source.koord_x as coordinate_x,
        source.koord_y as coordinate_y,
        'digiroad_r' as external_stop_point_source
    FROM :schema.dr_pysakki source
) TO STDOUT WITH (FORMAT CSV, HEADER)