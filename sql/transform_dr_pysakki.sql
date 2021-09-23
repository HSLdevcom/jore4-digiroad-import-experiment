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
-- Municipality filtering is done into `dr_linkki` table.
INNER JOIN :schema.dr_linkki link USING (link_id);

-- Replace input table with transformed output.
DROP TABLE :schema.dr_pysakki;
ALTER TABLE :schema.dr_pysakki_out RENAME TO dr_pysakki;

-- Add data integrity constraints.
\i :sql_dir/add_dr_pysakki_constraints.sql
