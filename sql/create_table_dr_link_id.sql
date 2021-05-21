DROP TABLE IF EXISTS :schema.dr_link_id;

CREATE TABLE :schema.dr_link_id AS
SELECT DISTINCT link_id
FROM :schema.dr_linkki_k
WHERE
    -- Filter in municipalities relevant to HSL.
    kuntakoodi IN (
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
    )
ORDER BY link_id ASC;

ALTER TABLE :schema.dr_link_id ADD CONSTRAINT dr_link_id_pkey PRIMARY KEY (link_id);
