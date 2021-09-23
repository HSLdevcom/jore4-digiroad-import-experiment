-- Add data integrity constraints.
ALTER TABLE :schema.dr_pysakki ALTER COLUMN gid SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN link_id SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN kuntakoodi SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN koord_x SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN koord_y SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_pysakki ADD CONSTRAINT dr_pysakki_pkey PRIMARY KEY (gid);
ALTER TABLE :schema.dr_pysakki ADD CONSTRAINT fk_dr_pysakki_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_linkki (link_id);
