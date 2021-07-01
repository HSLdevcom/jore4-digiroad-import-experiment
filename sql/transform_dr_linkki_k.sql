DROP TABLE IF EXISTS digiroad.dr_linkki_out;

CREATE TABLE digiroad.dr_linkki_out AS
SELECT
    src.gid,
    src.link_id,
    src.link_mmlid,
    src.segm_id,
    src.kuntakoodi,
    src.hallinn_lk,
    src.toiminn_lk,
    src.linkkityyp,
    src.tienumero,
    src.tieosanro,
    src.silta_alik,
    src.ajorata,
    src.aet,
    src.let,
    src.ajosuunta,
    src.tienimi_su,
    src.tienimi_ru,
    src.tienimi_sa,
    src.ens_talo_o,
    src.ens_talo_v,
    src.viim_tal_o,
    src.viim_tal_v,
    src.muokkauspv,
    src.sij_tark,
    src.kor_tark,
    src.alku_paalu,
    src.lopp_paalu,
    src.geom_flip,
    src.link_tila,
    src.geom_lahde,
    src.mtk_tie_lk,
    src.tien_kasvu,
    src.geom AS geom_orig
FROM digiroad.dr_linkki_k src;

UPDATE digiroad.dr_linkki_out SET geom_orig = ST_SetSRID(geom_orig, 3067);

SELECT AddGeometryColumn('digiroad', 'dr_linkki_out', 'geom', 3067, 'LINESTRING', 3);
UPDATE digiroad.dr_linkki_out SET geom = ST_Force3D(geom_orig);
ALTER TABLE digiroad.dr_linkki_out ALTER COLUMN geom SET NOT NULL;

ALTER TABLE digiroad.dr_linkki_out ADD COLUMN geog geography(LINESTRINGZ, 4326);
UPDATE digiroad.dr_linkki_out SET geog = Geography(ST_Transform(geom, 4326));
ALTER TABLE digiroad.dr_linkki_out ALTER COLUMN geog SET NOT NULL;

ALTER TABLE digiroad.dr_linkki_out DROP COLUMN geom_orig;

-- Replace input table with transformed output.
DROP TABLE digiroad.dr_linkki_k;
ALTER TABLE digiroad.dr_linkki_out RENAME TO dr_linkki_k;
