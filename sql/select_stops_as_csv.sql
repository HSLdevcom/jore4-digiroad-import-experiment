COPY (
    SELECT
        source.gid as external_stop_id,
        source.link_id as external_link_id,
        source.valtak_id as national_stop_id,
        CASE
            WHEN source.vaik_suunt = 2 THEN 'forward'
            WHEN source.vaik_suunt = 3 THEN 'backward'
        END AS direction_on_infra_link,
        ST_AsGeoJSON(ST_Transform(source.geom, 4326))::jsonb as location,
        source.nimi_su as finnish_name,
        source.nimi_ru as swedish_name,
        'digiroad_r' as external_stop_source
    FROM :schema.dr_pysakki source
) TO STDOUT WITH (FORMAT CSV, HEADER)