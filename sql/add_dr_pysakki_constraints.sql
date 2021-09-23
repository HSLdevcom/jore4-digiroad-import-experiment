ALTER TABLE :schema.dr_pysakki ALTER COLUMN gid SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN link_id SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN kuntakoodi SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN koord_x SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN koord_y SET NOT NULL;
ALTER TABLE :schema.dr_pysakki ALTER COLUMN geom SET NOT NULL;

ALTER TABLE :schema.dr_pysakki ADD CONSTRAINT dr_pysakki_pkey PRIMARY KEY (gid);
