DROP TABLE IF EXISTS :schema.dr_linkki_out;

CREATE TABLE :schema.dr_linkki_out AS
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

    -- custom segment order
    row_number() OVER (
        PARTITION BY src.link_id
        ORDER BY src.segm_id ASC
     )::int AS segm_order,

    src.geom
FROM :schema.dr_linkki_k src
-- Municipality filtering is done into `dr_link_id` table.
INNER JOIN :schema.dr_link_id l USING (link_id)
WHERE
    src.linkkityyp IN (
        1, -- Moottoritien osa
        2, -- Moniajorataisen tien osa, joka ei ole moottoritie
        3, -- Yksiajorataisen tien osa
        4, -- Moottoriliikennetien osa
        5, -- Kiertoliittymän osa
        6, -- Ramppi
    --  7, -- Levähdysalue
    --  8, -- Pyörätie tai yhdistetty pyörätie ja jalkakäytävä
    --  9, -- Jalankulkualueen osa, esim. kävelykatu tai jalkakäytävä
    -- 10, -- Huolto- tai pelastustien osa
       11, -- Liitännäisliikennealueen osa
    -- 12, -- Ajopolku, maastoajoneuvolla ajettavissa olevat tiet
    -- 13, -- Huoltoaukko moottoritiellä
    -- 14, -- Erikoiskuljetusyhteys ilman puomia
    -- 15, -- Erikoiskuljetusyhteys puomilla
       21  -- Lossi
    );

-- Replace input table with transformed output.
DROP TABLE :schema.dr_linkki_k;
ALTER TABLE :schema.dr_linkki_out RENAME TO dr_linkki_k;

-- Add data integrity constraints.
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN link_id SET NOT NULL;
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN segm_id SET NOT NULL;
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN kuntakoodi SET NOT NULL;
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN linkkityyp SET NOT NULL;
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN ajosuunta SET NOT NULL;

ALTER TABLE :schema.dr_linkki_k ADD CONSTRAINT dr_linkki_k_pkey PRIMARY KEY (gid);
ALTER TABLE :schema.dr_linkki_k ADD CONSTRAINT uk_dr_linkki_k_segm_id UNIQUE (segm_id);
ALTER TABLE :schema.dr_linkki_k ADD CONSTRAINT fk_dr_linkki_k_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_link_id (link_id);
