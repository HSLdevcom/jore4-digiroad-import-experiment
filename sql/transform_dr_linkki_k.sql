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
    src.geom AS geom_orig
FROM :schema.dr_linkki_k src
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
    )
    -- Filter in municipalities relevant to HSL.
    AND src.kuntakoodi IN (
       49, -- Espoo,
       91, -- Helsinki
      186, -- Järvenpää
      235, -- Kauniainen
      245, -- Kerava
      257, -- Kirkkonummi
      753, -- Sipoo
      755, -- Siuntio
      858, -- Tuusula
       92  -- Vantaa
    );

UPDATE :schema.dr_linkki_out SET geom_orig = ST_SetSRID(geom_orig, 3067);

SELECT AddGeometryColumn(:'schema', 'dr_linkki_out', 'geom', 3067, 'LINESTRING', 3);
UPDATE :schema.dr_linkki_out SET geom = ST_Force3D(geom_orig);
ALTER TABLE :schema.dr_linkki_out ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_linkki_out ADD COLUMN geog geography(LINESTRINGZ, 4326);
UPDATE :schema.dr_linkki_out SET geog = Geography(ST_Transform(geom, 4326));
ALTER TABLE :schema.dr_linkki_out ALTER COLUMN geog SET NOT NULL;

ALTER TABLE :schema.dr_linkki_out DROP COLUMN geom_orig;

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
