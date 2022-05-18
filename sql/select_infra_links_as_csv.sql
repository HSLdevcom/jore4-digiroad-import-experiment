COPY (
    SELECT
        source.link_id as external_link_id,
        source.hsl_infra_source as external_link_source,
        ST_AsGeoJSON(ST_Transform(source.geom, 4326))::jsonb as shape,
        CASE
            WHEN source.ajosuunta = 2 THEN 'bidirectional'
            WHEN source.ajosuunta = 3 THEN 'backward'
            WHEN source.ajosuunta = 4 THEN 'forward'
        END AS direction,
        ST_Length(source.geom) as estimated_length_in_metres
    FROM :schema.dr_linkki_fixup source
    WHERE source.ajosuunta IN (2, 3, 4) -- filter out possibly invalid links
) TO STDOUT WITH (FORMAT CSV, HEADER)
