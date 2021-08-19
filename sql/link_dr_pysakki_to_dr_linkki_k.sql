WITH single_part_link_ids AS (
    SELECT link_id
    FROM :schema.dr_linkki_k
    GROUP BY link_id
    HAVING count(*) = 1
),
link_stop_ids AS (
    SELECT stop.gid AS stop_gid, link.gid AS link_gid
    FROM :schema.dr_pysakki stop
    INNER JOIN single_part_link_ids link_ids USING (link_id)
    INNER JOIN :schema.dr_linkki_k link USING (link_id)
)
UPDATE :schema.dr_pysakki
SET link_gid = ids.link_gid
FROM link_stop_ids ids
WHERE gid = ids.stop_gid;

WITH multi_part_link_ids AS (
    SELECT link_id, count(*) AS segm_count
    FROM :schema.dr_linkki_k
    GROUP BY link_id
    HAVING count(*) >= 2
),
filtered_stops AS (
    SELECT gid, link_id, geom
    FROM :schema.dr_pysakki stop
    INNER JOIN multi_part_link_ids link_ids USING (link_id)
),
link_part_stop_dist AS (
    SELECT
        stop.gid AS stop_gid,
        link.link_id,
        link.gid AS link_gid,
        ST_Distance(stop.geom, ST_ClosestPoint(link.geom, stop.geom)) AS stop_dist
    FROM filtered_stops stop
    INNER JOIN :schema.dr_linkki_k link USING (link_id)
),
closest_link_parts AS (
    SELECT DISTINCT ON (stop_gid) stop_gid, link_id, link_gid, stop_dist
    FROM link_part_stop_dist
    ORDER BY stop_gid, stop_dist
)
UPDATE :schema.dr_pysakki
SET link_gid = link_parts.link_gid
FROM closest_link_parts link_parts
WHERE gid = link_parts.stop_gid;

DELETE FROM :schema.dr_pysakki WHERE link_gid IS NULL; -- There are only a few which are not associated with a link.
ALTER TABLE :schema.dr_pysakki ALTER COLUMN link_gid SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ADD CONSTRAINT fk_dr_pysakki_link_gid FOREIGN KEY (link_gid) REFERENCES :schema.dr_linkki_k (gid);
