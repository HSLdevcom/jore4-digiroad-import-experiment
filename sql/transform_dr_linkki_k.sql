DROP TABLE IF EXISTS digiroad.dr_linkki_out;

CREATE TABLE digiroad.dr_linkki_out AS
SELECT
    src.gid AS gid,
    src.link_id AS link_id,
    src.link_mmlid AS link_mmlid,
    src.segm_id AS segm_id,
    src.kuntakoodi AS kuntakoodi,
    src.hallinn_lk AS hallinn_lk,
    src.toiminn_lk AS toiminn_lk,
    src.linkkityyp AS linkkityyp,
    src.tienumero AS tienumero,
    src.tieosanro AS tieosanro,
    src.silta_alik AS silta_alik,
    src.ajorata AS ajorata,
    src.aet AS aet,
    src.let AS let,
    src.ajosuunta AS ajosuunta,
    src.tienimi_su AS tienimi_su,
    src.tienimi_ru AS tienimi_ru,
    src.tienimi_sa AS tienimi_sa,
    src.ens_talo_o AS ens_talo_o,
    src.ens_talo_v AS ens_talo_v,
    src.viim_tal_o AS viim_tal_o,
    src.viim_tal_v AS viim_tal_v,
    src.muokkauspv AS muokkauspv,
    src.sij_tark AS sij_tark,
    src.kor_tark AS kor_tark,
    src.alku_paalu AS alku_paalu,
    src.lopp_paalu AS lopp_paalu,
    src.geom_flip AS geom_flip,
    src.link_tila AS link_tila,
    src.geom_lahde AS geom_lahde,
    src.mtk_tie_lk AS mtk_tie_lk,
    src.tien_kasvu AS tien_kasvu,
    (ST_Dump(src.geom)).geom AS geom_dump
FROM digiroad.dr_linkki_k src;

UPDATE digiroad.dr_linkki_out SET geom_dump = ST_SetSRID(geom_dump, 3067);

SELECT AddGeometryColumn('digiroad', 'dr_linkki_out', 'geom', 3067, 'LINESTRING', 3);
UPDATE digiroad.dr_linkki_out SET geom = ST_Force3D(geom_dump);
ALTER TABLE digiroad.dr_linkki_out ALTER COLUMN geom SET NOT NULL;

ALTER TABLE digiroad.dr_linkki_out ADD COLUMN geog geography(LINESTRINGZ, 4326);
UPDATE digiroad.dr_linkki_out SET geog = Geography(ST_Transform(geom, 4326));
ALTER TABLE digiroad.dr_linkki_out ALTER COLUMN geog SET NOT NULL;

ALTER TABLE digiroad.dr_linkki_out DROP COLUMN geom_dump;

-- Replace input table with transformed output.
DROP TABLE digiroad.dr_linkki_k;
ALTER TABLE digiroad.dr_linkki_out RENAME TO dr_linkki_k;
