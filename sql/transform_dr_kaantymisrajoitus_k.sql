DROP TABLE IF EXISTS :schema.dr_kaantymisrajoitus_out;

CREATE TABLE :schema.dr_kaantymisrajoitus_out AS
SELECT
    src.id,
    src.lahd_id,
    src.kohd_id,
    src.kuntakoodi,
    src.poikkeus,
    src.voim_aika,
    src.lisatiedot,
    src.muokkauspv,
    src.geom AS geom_orig
FROM :schema.dr_kaantymisrajoitus_k src
-- Municipality filtering is done into `dr_link_id` table.
INNER JOIN :schema.dr_link_id lahd ON lahd.link_id = src.lahd_id
INNER JOIN :schema.dr_link_id kohd ON kohd.link_id = src.kohd_id;

SELECT AddGeometryColumn(:'schema', 'dr_kaantymisrajoitus_out', 'geom', 3067, 'LINESTRING', 3);
UPDATE :schema.dr_kaantymisrajoitus_out SET geom = ST_Force3D(geom_orig);
ALTER TABLE :schema.dr_kaantymisrajoitus_out ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_kaantymisrajoitus_out DROP COLUMN geom_orig;

-- Replace input table with transformed output.
DROP TABLE :schema.dr_kaantymisrajoitus_k;
ALTER TABLE :schema.dr_kaantymisrajoitus_out RENAME TO dr_kaantymisrajoitus_k;

-- Add data integrity constraints.
ALTER TABLE :schema.dr_kaantymisrajoitus_k ALTER COLUMN id SET NOT NULL;
ALTER TABLE :schema.dr_kaantymisrajoitus_k ALTER COLUMN lahd_id SET NOT NULL;
ALTER TABLE :schema.dr_kaantymisrajoitus_k ALTER COLUMN kohd_id SET NOT NULL;
ALTER TABLE :schema.dr_kaantymisrajoitus_k ALTER COLUMN kuntakoodi SET NOT NULL;

ALTER TABLE :schema.dr_kaantymisrajoitus_k ADD CONSTRAINT dr_kaantymisrajoitus_k_pkey PRIMARY KEY (id);
ALTER TABLE :schema.dr_kaantymisrajoitus_k ADD CONSTRAINT fk_dr_kaantymisrajoitus_k_lahd_id FOREIGN KEY (lahd_id) REFERENCES :schema.dr_link_id (link_id);
ALTER TABLE :schema.dr_kaantymisrajoitus_k ADD CONSTRAINT fk_dr_kaantymisrajoitus_k_kohd_id FOREIGN KEY (kohd_id) REFERENCES :schema.dr_link_id (link_id);
