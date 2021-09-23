DROP TABLE IF EXISTS :schema.dr_pysakki_out;

CREATE TABLE :schema.dr_pysakki_out AS
SELECT
    src.gid,
    src.link_id,
    src.link_mmlid,
    src.valtak_id,
    src.kuntakoodi,
    src.koord_x,
    src.koord_y,
    src.sijainti_m,
    src.vaik_suunt,
    src.nimi_su,
    src.nimi_ru,
    src.yllapitaja,
    src.yllap_tunn,
    src.livi_tunn,
    src.matk_tunn,
    src.maast_x,
    src.maast_y,
    src.maast_z,
    src.liik_suunt,
    src.l_suuntima,
    src.ens_vo_pv,
    src.viim_vo_pv,
    src.pys_tyyppi,
    src.aikataulu,
    src.katos,
    src.penkki,
    src.mainoskat,
    src.pyoratelin,
    src.s_aikataul,
    src.valaistus,
    src.estettomyy,
    src.saattomahd,
    src.liit_lkm,
    src.liit_lisat,
    src.pys_omist,
    src.palaute_os,
    src.lisatiedot,
    src.irti_geom,
    src.muokkauspv,
    src.laiturinum,
    src.liit_term,
    src.vyohyktiet,
    src.palvelutas,
    src.geom
FROM :schema.dr_pysakki src
-- Municipality filtering is done into `dr_link_id` table.
INNER JOIN :schema.dr_link_id link_ids USING (link_id);

-- Replace input table with transformed output.
DROP TABLE :schema.dr_pysakki;
ALTER TABLE :schema.dr_pysakki_out RENAME TO dr_pysakki;

-- Add common data integrity constraints to `dr_pysakki` table.
\i :sql_dir/add_dr_pysakki_constraints.sql

ALTER TABLE :schema.dr_pysakki ADD CONSTRAINT fk_dr_pysakki_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_link_id (link_id);

-- Add foreign key reference to `dr_linkki_k` table.

ALTER TABLE :schema.dr_pysakki ADD COLUMN link_gid INTEGER;

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
