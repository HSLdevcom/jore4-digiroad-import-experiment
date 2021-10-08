ALTER TABLE :schema.dr_linkki

    ALTER COLUMN link_id SET NOT NULL,
    ALTER COLUMN kuntakoodi SET NOT NULL,
    ALTER COLUMN linkkityyp SET NOT NULL,
    ALTER COLUMN ajosuunta SET NOT NULL,

    ADD CONSTRAINT dr_linkki_pkey PRIMARY KEY (gid),
    ADD CONSTRAINT uk_dr_linkki_link_id UNIQUE (link_id);
