WITH to_be_removed AS (
    SELECT link_id
    FROM :schema.dr_linkki
    WHERE EXISTS (
        SELECT 1
        FROM :schema.removed_links
        WHERE ST_Intersects(dr_linkki.geom, removed_links.geometry)
    )
),
dummy AS (
    DELETE FROM :schema.dr_pysakki 
    USING to_be_removed
    WHERE dr_pysakki.link_id = to_be_removed.link_id
)
DELETE FROM :schema.dr_linkki
USING to_be_removed
WHERE dr_linkki.link_id = to_be_removed.link_id;
