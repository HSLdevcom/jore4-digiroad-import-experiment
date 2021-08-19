ALTER TABLE :schema.dr_linkki_k ALTER COLUMN link_id SET NOT NULL;
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN segm_id SET NOT NULL;
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN kuntakoodi SET NOT NULL;
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN linkkityyp SET NOT NULL;
ALTER TABLE :schema.dr_linkki_k ALTER COLUMN ajosuunta SET NOT NULL;

ALTER TABLE :schema.dr_linkki_k ADD CONSTRAINT dr_linkki_k_pkey PRIMARY KEY (gid);
ALTER TABLE :schema.dr_linkki_k ADD CONSTRAINT uk_dr_linkki_k_segm_id UNIQUE (segm_id);
ALTER TABLE :schema.dr_linkki_k ADD CONSTRAINT fk_dr_linkki_k_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_link_id (link_id);
