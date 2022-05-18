DROP TABLE IF EXISTS :schema.dr_pysakki_out;

CREATE TABLE :schema.dr_pysakki_out AS
SELECT
    src.gid,
    src.link_id::text,
    src.link_mmlid,
    src.valtak_id::int,
    src.kuntakoodi::int,
    src.koord_x,
    src.koord_y,
    src.sijainti_m,
    src.vaik_suunt::int,
    src.nimi_su,
    src.nimi_ru,
    src.yllapitaja::int,
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
    src.aikataulu::int,
    src.katos::int,
    src.penkki::int,
    src.mainoskat::int,
    src.pyoratelin::int,
    src.s_aikataul::int,
    src.valaistus::int,
    src.estettomyy,
    src.saattomahd::int,
    src.liit_lkm,
    src.liit_lisat,
    src.pys_omist,
    src.palaute_os,
    src.lisatiedot,
    src.irti_geom::int,
    src.muokkauspv,
    src.laiturinum,
    src.liit_term,
    src.vyohyktiet,
    src.palvelutas,
    src.geom
FROM :schema.dr_pysakki src
-- Municipality filtering is done into `dr_linkki` table.
INNER JOIN :schema.dr_linkki link USING (link_id);

-- Replace input table with transformed output.
DROP TABLE :schema.dr_pysakki;
ALTER TABLE :schema.dr_pysakki_out RENAME TO dr_pysakki;

-- Add data integrity constraints.
ALTER TABLE :schema.dr_pysakki

    ALTER COLUMN gid SET NOT NULL,
    ALTER COLUMN link_id SET NOT NULL,
    ALTER COLUMN valtak_id SET NOT NULL,
    ALTER COLUMN kuntakoodi SET NOT NULL,
    ALTER COLUMN koord_x SET NOT NULL,
    ALTER COLUMN koord_y SET NOT NULL,
    ALTER COLUMN sijainti_m SET NOT NULL,
    ALTER COLUMN vaik_suunt SET NOT NULL,
    ALTER COLUMN geom SET NOT NULL,

    ADD CONSTRAINT dr_pysakki_pkey PRIMARY KEY (gid),
    ADD CONSTRAINT fk_dr_pysakki_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_linkki (link_id);
