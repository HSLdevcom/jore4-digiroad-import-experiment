DROP TABLE IF EXISTS :schema.dr_pysakki_out;

CREATE TABLE :schema.dr_pysakki_out AS
SELECT src.*
FROM :schema.dr_pysakki src
-- Municipality filtering is done into `dr_linkki` table.
INNER JOIN :schema.dr_linkki link USING (link_id);

ALTER TABLE :schema.dr_pysakki_out
    ALTER COLUMN link_id TYPE text,
    ALTER COLUMN valtak_id TYPE int,
    ALTER COLUMN kuntakoodi TYPE int,
    ALTER COLUMN vaik_suunt TYPE int,
    ALTER COLUMN nimi_su TYPE text,
    ALTER COLUMN nimi_ru TYPE text,
    ALTER COLUMN yllapitaja TYPE int,
    ALTER COLUMN matk_tunn TYPE text,
    ALTER COLUMN aikataulu TYPE int,
    ALTER COLUMN katos TYPE int,
    ALTER COLUMN penkki TYPE int,
    ALTER COLUMN mainoskat TYPE int,
    ALTER COLUMN pyoratelin TYPE int,
    ALTER COLUMN s_aikataul TYPE int,
    ALTER COLUMN valaistus TYPE int,
    ALTER COLUMN saattomahd TYPE int,
    ALTER COLUMN irti_geom TYPE int;

ALTER TABLE :schema.dr_pysakki_out RENAME COLUMN gid TO id;

-- Replace input table with transformed output.
DROP TABLE :schema.dr_pysakki;
ALTER TABLE :schema.dr_pysakki_out RENAME TO dr_pysakki;

-- Add data integrity constraints.
ALTER TABLE :schema.dr_pysakki

    ALTER COLUMN id SET NOT NULL,
    ALTER COLUMN link_id SET NOT NULL,
    ALTER COLUMN valtak_id SET NOT NULL,
    ALTER COLUMN kuntakoodi SET NOT NULL,
    ALTER COLUMN koord_x SET NOT NULL,
    ALTER COLUMN koord_y SET NOT NULL,
    ALTER COLUMN sijainti_m SET NOT NULL,
    ALTER COLUMN vaik_suunt SET NOT NULL,
    ALTER COLUMN geom SET NOT NULL,

    ADD CONSTRAINT dr_pysakki_pkey PRIMARY KEY (id),
    ADD CONSTRAINT fk_dr_pysakki_link_id FOREIGN KEY (link_id) REFERENCES :schema.dr_linkki (link_id);

CREATE INDEX dr_pysakki_link_id_idx ON :schema.dr_pysakki (link_id);
CREATE INDEX dr_pysakki_valtak_id_idx ON :schema.dr_pysakki (valtak_id);
