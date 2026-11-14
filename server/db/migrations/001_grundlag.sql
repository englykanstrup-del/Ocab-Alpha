-- 001_grundlag.sql
-- Første version af datamodellen for Ocab Alpha og Ocab Arbejdsordre.
-- Godkendt af projektlederen 2026-11-14.
--
-- Regler for alle tabeller:
--   * id er en UUID, som også kan laves på telefonen uden net.
--   * oprettet/aendret og hvem der gjorde det gemmes på hver række.
--   * Intet slettes helt: rækker arkiveres (arkiveret_tid sættes).

-- ---------------------------------------------------------------------------
-- Hjælpefunktion: opdater "aendret" automatisk
-- ---------------------------------------------------------------------------
CREATE FUNCTION saet_aendret() RETURNS trigger AS $$
BEGIN
  NEW.aendret := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Medarbejdere og login
-- ---------------------------------------------------------------------------
CREATE TABLE medarbejder (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  navn            text NOT NULL,
  email           text UNIQUE,
  telefon         text,
  rolle           text NOT NULL CHECK (rolle IN ('admin', 'projektleder', 'vagtleder', 'sanitoer')),
  postnummer      text,
  bredde          numeric(9, 6),
  laengde         numeric(9, 6),
  har_vagt        boolean NOT NULL DEFAULT false,
  aktiv           boolean NOT NULL DEFAULT true,
  oprettet        timestamptz NOT NULL DEFAULT now(),
  oprettet_af     uuid REFERENCES medarbejder(id),
  aendret         timestamptz NOT NULL DEFAULT now(),
  aendret_af      uuid REFERENCES medarbejder(id),
  arkiveret_tid   timestamptz
);

CREATE TABLE login (
  medarbejder_id    uuid PRIMARY KEY REFERENCES medarbejder(id),
  email             text NOT NULL UNIQUE,
  adgangskode_hash  text,            -- personligt login (test)
  microsoft_id      text UNIQUE,     -- Microsoft 365-login senere
  sidst_logget_ind  timestamptz,
  oprettet          timestamptz NOT NULL DEFAULT now(),
  aendret           timestamptz NOT NULL DEFAULT now(),
  CHECK (adgangskode_hash IS NOT NULL OR microsoft_id IS NOT NULL)
);

-- ---------------------------------------------------------------------------
-- Faste lister, som admin kan rette
-- ---------------------------------------------------------------------------
CREATE TABLE skadetype (
  kode      text PRIMARY KEY,
  navn      text NOT NULL,
  raekkefolge int NOT NULL DEFAULT 0,
  aktiv     boolean NOT NULL DEFAULT true
);

CREATE TABLE faggruppe (
  kode      text PRIMARY KEY,
  navn      text NOT NULL,
  raekkefolge int NOT NULL DEFAULT 0,
  aktiv     boolean NOT NULL DEFAULT true
);

-- ---------------------------------------------------------------------------
-- Kunder og sager
-- ---------------------------------------------------------------------------
CREATE TABLE kunde (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  navn            text NOT NULL,
  type            text NOT NULL CHECK (type IN ('forsikring', 'erhverv', 'privat')),
  cvr             text,
  email           text,
  telefon         text,
  adresse         text,
  aftalekunde     text,            -- styrer priser i fase 2 (fx Tryg, Standard -10 %)
  oprettet        timestamptz NOT NULL DEFAULT now(),
  oprettet_af     uuid REFERENCES medarbejder(id),
  aendret         timestamptz NOT NULL DEFAULT now(),
  aendret_af      uuid REFERENCES medarbejder(id),
  arkiveret_tid   timestamptz
);

CREATE TABLE kontaktperson (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kunde_id        uuid NOT NULL REFERENCES kunde(id),
  navn            text NOT NULL,
  titel           text,
  telefon         text,
  email           text,
  oprettet        timestamptz NOT NULL DEFAULT now(),
  oprettet_af     uuid REFERENCES medarbejder(id),
  aendret         timestamptz NOT NULL DEFAULT now(),
  aendret_af      uuid REFERENCES medarbejder(id),
  arkiveret_tid   timestamptz
);

-- Sagsnummer: år og løbenummer, fx 2026-0142
CREATE TABLE sagsnummer_taeller (
  aar       int PRIMARY KEY,
  sidste    int NOT NULL
);

CREATE FUNCTION naeste_sagsnummer() RETURNS text AS $$
DECLARE
  dette_aar int := extract(year FROM now())::int;
  nr int;
BEGIN
  INSERT INTO sagsnummer_taeller (aar, sidste) VALUES (dette_aar, 1)
  ON CONFLICT (aar) DO UPDATE SET sidste = sagsnummer_taeller.sidste + 1
  RETURNING sidste INTO nr;
  RETURN dette_aar::text || '-' || lpad(nr::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

CREATE TABLE sag (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sagsnummer            text NOT NULL UNIQUE DEFAULT naeste_sagsnummer(),
  status                text NOT NULL DEFAULT 'ny'
                        CHECK (status IN ('ny', 'aktiv', 'afventer', 'afsluttet', 'faktureret')),
  sagsejer_id           uuid REFERENCES medarbejder(id),
  kunde_id              uuid REFERENCES kunde(id),          -- betaler
  forsikringsselskab_id uuid REFERENCES kunde(id),
  skadenummer           text,
  sagsbehandler_id      uuid REFERENCES kontaktperson(id),
  skadetype             text REFERENCES skadetype(kode),
  kilde                 text CHECK (kilde IN ('skafor', 'forsikring', 'mail', 'telefon', 'andet')),
  skadedato             date,
  skadeadresse          text NOT NULL,
  postnummer            text,
  by                    text,
  bredde                numeric(9, 6),
  laengde               numeric(9, 6),
  kontakt_paa_stedet    text,
  kontakt_telefon       text,
  hvad_er_sket          text,
  bygningsbeskrivelse   text,
  adgang                text,
  oprettet              timestamptz NOT NULL DEFAULT now(),
  oprettet_af           uuid REFERENCES medarbejder(id),
  aendret               timestamptz NOT NULL DEFAULT now(),
  aendret_af            uuid REFERENCES medarbejder(id),
  arkiveret_tid         timestamptz
);
CREATE INDEX sag_status_idx ON sag (status) WHERE arkiveret_tid IS NULL;
CREATE INDEX sag_sagsejer_idx ON sag (sagsejer_id);
CREATE INDEX sag_skadenummer_idx ON sag (skadenummer);

CREATE TABLE noegle (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sag_id          uuid NOT NULL REFERENCES sag(id),
  beskrivelse     text,
  hvor_ligger     text,
  hvem_har_id     uuid REFERENCES medarbejder(id),
  afleveres_til   text,
  afleveret_tid   timestamptz,
  oprettet        timestamptz NOT NULL DEFAULT now(),
  oprettet_af     uuid REFERENCES medarbejder(id),
  aendret         timestamptz NOT NULL DEFAULT now(),
  aendret_af      uuid REFERENCES medarbejder(id),
  arkiveret_tid   timestamptz
);

CREATE TABLE note (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sag_id          uuid NOT NULL REFERENCES sag(id),
  arbejdsordre_id uuid,            -- sættes, når noten er skrevet på en ordre (fremmednøgle tilføjes nedenfor)
  tekst           text NOT NULL,
  vigtig          boolean NOT NULL DEFAULT false,   -- "vigtigt fra kontoret"
  oprettet        timestamptz NOT NULL DEFAULT now(),
  oprettet_af     uuid REFERENCES medarbejder(id),
  aendret         timestamptz NOT NULL DEFAULT now(),
  aendret_af      uuid REFERENCES medarbejder(id),
  arkiveret_tid   timestamptz
);
CREATE INDEX note_sag_idx ON note (sag_id);

-- Sagsloggen skrives af serveren, rettes aldrig
CREATE TABLE sagslog (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sag_id          uuid NOT NULL REFERENCES sag(id),
  tidspunkt       timestamptz NOT NULL DEFAULT now(),
  medarbejder_id  uuid REFERENCES medarbejder(id),
  haendelse       text NOT NULL,       -- fx 'ordre_oprettet', 'rapport_sendt'
  tekst           text,
  data            jsonb                -- detaljer til visning, ikke til søgning
);
CREATE INDEX sagslog_sag_idx ON sagslog (sag_id, tidspunkt);

-- ---------------------------------------------------------------------------
-- Biler (før arbejdsordrer, fordi materialer trækkes fra en bil)
-- ---------------------------------------------------------------------------
CREATE TABLE bil (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nummerplade             text NOT NULL UNIQUE,
  type                    text,
  ansvarlig_id            uuid REFERENCES medarbejder(id),   -- tom = står i firmaet
  hjemsted_postnummer     text,
  bemaerkning             text,
  oprettet                timestamptz NOT NULL DEFAULT now(),
  oprettet_af             uuid REFERENCES medarbejder(id),
  aendret                 timestamptz NOT NULL DEFAULT now(),
  aendret_af              uuid REFERENCES medarbejder(id),
  arkiveret_tid           timestamptz
);

-- Simpelt vareregister nu. Lager og priser bygges ud i fase 2 og 3.
CREATE TABLE vare (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  varenummer      text UNIQUE,
  navn            text NOT NULL,
  enhed           text NOT NULL DEFAULT 'stk',
  er_udstyr       boolean NOT NULL DEFAULT false,   -- udstyr bliver i bilen, materialer forbruges
  oprettet        timestamptz NOT NULL DEFAULT now(),
  oprettet_af     uuid REFERENCES medarbejder(id),
  aendret         timestamptz NOT NULL DEFAULT now(),
  aendret_af      uuid REFERENCES medarbejder(id),
  arkiveret_tid   timestamptz
);

CREATE TABLE bilindhold (
  bil_id          uuid NOT NULL REFERENCES bil(id),
  vare_id         uuid NOT NULL REFERENCES vare(id),
  antal           numeric(10, 2) NOT NULL DEFAULT 0,
  aendret         timestamptz NOT NULL DEFAULT now(),
  aendret_af      uuid REFERENCES medarbejder(id),
  PRIMARY KEY (bil_id, vare_id)
);

CREATE TABLE biloptaelling (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bil_id          uuid NOT NULL REFERENCES bil(id),
  medarbejder_id  uuid REFERENCES medarbejder(id),
  anmodet_tid     timestamptz NOT NULL DEFAULT now(),
  udfyldt_tid     timestamptz,
  oprettet        timestamptz NOT NULL DEFAULT now(),
  oprettet_af     uuid REFERENCES medarbejder(id)
);

CREATE TABLE biloptaelling_linje (
  biloptaelling_id  uuid NOT NULL REFERENCES biloptaelling(id),
  vare_id           uuid NOT NULL REFERENCES vare(id),
  forventet         numeric(10, 2),
  talt              numeric(10, 2),
  PRIMARY KEY (biloptaelling_id, vare_id)
);

-- ---------------------------------------------------------------------------
-- Arbejdsordrer
-- ---------------------------------------------------------------------------
CREATE TABLE arbejdsordre (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sag_id              uuid NOT NULL REFERENCES sag(id),
  type                text NOT NULL CHECK (type IN
                        ('udkald', 'opstart', 'opstilling', 'aflaesning', 'nedtagning', 'besigtigelse', 'andet')),
  status              text NOT NULL DEFAULT 'kladde' CHECK (status IN
                        ('kladde', 'sendt', 'accepteret', 'i_gang', 'venter', 'afsluttet', 'annulleret')),
  titel               text,
  planlagt_start      timestamptz,
  planlagt_slut       timestamptz,
  opgaver_fra_kontoret text,
  kraevede_rapporter  text[] NOT NULL DEFAULT '{}',   -- koder fra rapportskabelon
  afsluttet_tid       timestamptz,
  oprettet            timestamptz NOT NULL DEFAULT now(),
  oprettet_af         uuid REFERENCES medarbejder(id),
  aendret             timestamptz NOT NULL DEFAULT now(),
  aendret_af          uuid REFERENCES medarbejder(id),
  arkiveret_tid       timestamptz
);
CREATE INDEX arbejdsordre_sag_idx ON arbejdsordre (sag_id);
CREATE INDEX arbejdsordre_status_idx ON arbejdsordre (status) WHERE arkiveret_tid IS NULL;

ALTER TABLE note ADD CONSTRAINT note_arbejdsordre_fk
  FOREIGN KEY (arbejdsordre_id) REFERENCES arbejdsordre(id);

CREATE TABLE ordre_deltager (
  arbejdsordre_id   uuid NOT NULL REFERENCES arbejdsordre(id),
  medarbejder_id    uuid NOT NULL REFERENCES medarbejder(id),
  svar              text NOT NULL DEFAULT 'afventer' CHECK (svar IN ('afventer', 'accepteret', 'afvist')),
  afvist_grund      text,
  svar_tid          timestamptz,
  koersel_startet   timestamptz,
  ankommet          timestamptz,
  afsluttet         timestamptz,
  laver_rapport     boolean NOT NULL DEFAULT false,
  oprettet          timestamptz NOT NULL DEFAULT now(),
  aendret           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (arbejdsordre_id, medarbejder_id),
  CHECK (svar <> 'afvist' OR afvist_grund IS NOT NULL)
);
CREATE INDEX ordre_deltager_medarbejder_idx ON ordre_deltager (medarbejder_id);

CREATE TABLE tjekpunkt (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arbejdsordre_id   uuid NOT NULL REFERENCES arbejdsordre(id),
  punkt             text NOT NULL,    -- fx 'facadebillede', 'noegle', 'maskiner', 'afslutning'
  udfoert_af        uuid REFERENCES medarbejder(id),
  udfoert_tid       timestamptz,
  bemaerkning       text,
  UNIQUE (arbejdsordre_id, punkt)
);

CREATE TABLE risikovurdering (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arbejdsordre_id   uuid NOT NULL REFERENCES arbejdsordre(id),
  medarbejder_id    uuid NOT NULL REFERENCES medarbejder(id),
  risici            text[] NOT NULL DEFAULT '{}',
  tiltag            text,
  tidspunkt         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE timeregistrering (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arbejdsordre_id   uuid NOT NULL REFERENCES arbejdsordre(id),
  medarbejder_id    uuid NOT NULL REFERENCES medarbejder(id),
  dato              date NOT NULL,
  timer             numeric(5, 2) NOT NULL CHECK (timer > 0 AND timer <= 24),
  faggruppe         text NOT NULL REFERENCES faggruppe(kode),
  overtid           boolean NOT NULL DEFAULT false,
  bemaerkning       text,
  oprettet          timestamptz NOT NULL DEFAULT now(),
  aendret           timestamptz NOT NULL DEFAULT now(),
  arkiveret_tid     timestamptz
);
CREATE INDEX timeregistrering_medarbejder_idx ON timeregistrering (medarbejder_id, dato);
CREATE INDEX timeregistrering_ordre_idx ON timeregistrering (arbejdsordre_id);

CREATE TABLE materialeforbrug (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arbejdsordre_id   uuid NOT NULL REFERENCES arbejdsordre(id),
  vare_id           uuid NOT NULL REFERENCES vare(id),
  antal             numeric(10, 2) NOT NULL CHECK (antal > 0),
  fra_bil_id        uuid REFERENCES bil(id),
  medarbejder_id    uuid REFERENCES medarbejder(id),
  oprettet          timestamptz NOT NULL DEFAULT now(),
  arkiveret_tid     timestamptz
);
CREATE INDEX materialeforbrug_ordre_idx ON materialeforbrug (arbejdsordre_id);

-- ---------------------------------------------------------------------------
-- Billeder og filer (selve filerne ligger i billedlageret)
-- ---------------------------------------------------------------------------
CREATE TABLE billede (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sag_id            uuid NOT NULL REFERENCES sag(id),
  arbejdsordre_id   uuid REFERENCES arbejdsordre(id),
  lager_noegle      text NOT NULL,       -- sti i billedlageret
  miniature_noegle  text,
  tekst             text,
  rum               text,                -- frit felt, fx "Køkken"
  med_i_rapport     boolean NOT NULL DEFAULT false,
  taget_af          uuid REFERENCES medarbejder(id),
  taget_tid         timestamptz,
  bredde_px         int,
  hoejde_px         int,
  oprettet          timestamptz NOT NULL DEFAULT now(),
  aendret           timestamptz NOT NULL DEFAULT now(),
  arkiveret_tid     timestamptz
);
CREATE INDEX billede_sag_idx ON billede (sag_id);
CREATE INDEX billede_ordre_idx ON billede (arbejdsordre_id);

CREATE TABLE fil (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sag_id            uuid NOT NULL REFERENCES sag(id),
  type              text NOT NULL CHECK (type IN ('pdf', 'mail', 'dokument', 'andet')),
  navn              text NOT NULL,
  lager_noegle      text NOT NULL,
  mime_type         text,
  stoerrelse_bytes  bigint,
  oprettet          timestamptz NOT NULL DEFAULT now(),
  oprettet_af       uuid REFERENCES medarbejder(id),
  arkiveret_tid     timestamptz
);
CREATE INDEX fil_sag_idx ON fil (sag_id);

-- ---------------------------------------------------------------------------
-- Maskiner
-- ---------------------------------------------------------------------------
CREATE TABLE maskintype (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  navn            text NOT NULL UNIQUE,
  kategori        text NOT NULL,     -- affugter, luftrenser, vandsuger, ozon, kanalblaeser, dykpumpe, varme, andet
  doegnpris       numeric(10, 2),
  aktiv           boolean NOT NULL DEFAULT true
);

CREATE TABLE maskine (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nummer          text NOT NULL UNIQUE,
  qr_kode         text NOT NULL UNIQUE,
  maskintype_id   uuid NOT NULL REFERENCES maskintype(id),
  model           text,
  serienummer     text,
  status          text NOT NULL DEFAULT 'lager'
                  CHECK (status IN ('lager', 'reserveret', 'i_bil', 'i_drift', 'service', 'udgaaet')),
  bil_id          uuid REFERENCES bil(id),            -- når status = i_bil
  reserveret_sag_id uuid REFERENCES sag(id),          -- når status = reserveret
  bemaerkning     text,
  oprettet        timestamptz NOT NULL DEFAULT now(),
  oprettet_af     uuid REFERENCES medarbejder(id),
  aendret         timestamptz NOT NULL DEFAULT now(),
  aendret_af      uuid REFERENCES medarbejder(id),
  arkiveret_tid   timestamptz
);

CREATE TABLE opstilling (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  maskine_id            uuid NOT NULL REFERENCES maskine(id),
  sag_id                uuid NOT NULL REFERENCES sag(id),
  opsat_ordre_id        uuid REFERENCES arbejdsordre(id),
  opsat_af              uuid REFERENCES medarbejder(id),
  opsat_tid             timestamptz NOT NULL DEFAULT now(),
  placering             text,           -- rum eller sted i bygningen
  nedtaget_ordre_id     uuid REFERENCES arbejdsordre(id),
  nedtaget_af           uuid REFERENCES medarbejder(id),
  nedtaget_tid          timestamptz,
  CHECK (nedtaget_tid IS NULL OR nedtaget_tid >= opsat_tid)
);
-- En maskine kan kun stå ét sted ad gangen
CREATE UNIQUE INDEX opstilling_aktiv_idx ON opstilling (maskine_id) WHERE nedtaget_tid IS NULL;
CREATE INDEX opstilling_sag_idx ON opstilling (sag_id);

CREATE TABLE aflaesning (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opstilling_id     uuid NOT NULL REFERENCES opstilling(id),
  arbejdsordre_id   uuid REFERENCES arbejdsordre(id),
  tidspunkt         timestamptz NOT NULL DEFAULT now(),
  timetaeller       numeric(10, 1),
  kwh               numeric(10, 2),
  billede_id        uuid REFERENCES billede(id),
  aflaest_af        uuid REFERENCES medarbejder(id)
);

-- Maskindøgn pr. opstilling (påbegyndte døgn tælles som hele)
CREATE VIEW maskindoegn AS
SELECT
  o.id AS opstilling_id,
  o.sag_id,
  o.maskine_id,
  o.opsat_tid,
  o.nedtaget_tid,
  GREATEST(1, ceil(extract(epoch FROM (coalesce(o.nedtaget_tid, now()) - o.opsat_tid)) / 86400))::int AS doegn
FROM opstilling o;

-- ---------------------------------------------------------------------------
-- Rapporter
-- ---------------------------------------------------------------------------
CREATE TABLE rapportskabelon (
  kode        text NOT NULL,      -- udkald, skafor, besigtigelse, fugt, beboerliste
  version     int NOT NULL,
  navn        text NOT NULL,
  felter      jsonb NOT NULL DEFAULT '[]',   -- skabelonens opbygning (felter, rækkefølge, typer)
  aktiv       boolean NOT NULL DEFAULT true,
  oprettet    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (kode, version)
);

CREATE TABLE rapport (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sag_id              uuid NOT NULL REFERENCES sag(id),
  arbejdsordre_id     uuid REFERENCES arbejdsordre(id),
  skabelon_kode       text NOT NULL,
  skabelon_version    int NOT NULL,
  status              text NOT NULL DEFAULT 'kladde'
                      CHECK (status IN ('kladde', 'klar_til_godkendelse', 'godkendt', 'sendt')),
  ansvarlig_id        uuid REFERENCES medarbejder(id),   -- "Jeg laver den"
  godkendt_af         uuid REFERENCES medarbejder(id),
  godkendt_tid        timestamptz,
  sendt_til           text,
  sendt_tid           timestamptz,
  pdf_fil_id          uuid REFERENCES fil(id),
  oprettet            timestamptz NOT NULL DEFAULT now(),
  oprettet_af         uuid REFERENCES medarbejder(id),
  aendret             timestamptz NOT NULL DEFAULT now(),
  aendret_af          uuid REFERENCES medarbejder(id),
  arkiveret_tid       timestamptz,
  FOREIGN KEY (skabelon_kode, skabelon_version) REFERENCES rapportskabelon(kode, version)
);
CREATE INDEX rapport_sag_idx ON rapport (sag_id);

CREATE TABLE rapportfelt (
  rapport_id    uuid NOT NULL REFERENCES rapport(id),
  felt          text NOT NULL,
  vaerdi        text,
  aendret       timestamptz NOT NULL DEFAULT now(),
  aendret_af    uuid REFERENCES medarbejder(id),
  PRIMARY KEY (rapport_id, felt)
);

CREATE TABLE fugtmaaling (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rapport_id    uuid NOT NULL REFERENCES rapport(id),
  rum           text NOT NULL,
  punkt         text NOT NULL,
  vaerdi        numeric(6, 2) NOT NULL,
  enhed         text NOT NULL DEFAULT '%',
  maalt_dato    date NOT NULL,
  bemaerkning   text
);
CREATE INDEX fugtmaaling_rapport_idx ON fugtmaaling (rapport_id);

CREATE TABLE beboer (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rapport_id    uuid NOT NULL REFERENCES rapport(id),
  adresse       text NOT NULL,
  navn          text,
  telefon       text,
  email         text,
  bemaerkning   text,
  raekkefolge   int NOT NULL DEFAULT 0
);
CREATE INDEX beboer_rapport_idx ON beboer (rapport_id);

-- ---------------------------------------------------------------------------
-- Kort: gemte køreafstande
-- ---------------------------------------------------------------------------
CREATE TABLE afstand (
  fra_postnummer  text NOT NULL,
  til_bredde      numeric(9, 6) NOT NULL,
  til_laengde     numeric(9, 6) NOT NULL,
  km              numeric(7, 1) NOT NULL,
  minutter        int NOT NULL,
  beregnet        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (fra_postnummer, til_bredde, til_laengde)
);

-- ---------------------------------------------------------------------------
-- "aendret" opdateres automatisk på alle tabeller, der har kolonnen
-- ---------------------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOR t IN
    SELECT c.table_name FROM information_schema.columns c
    JOIN information_schema.tables tb ON tb.table_name = c.table_name AND tb.table_schema = c.table_schema
    WHERE c.table_schema = current_schema() AND c.column_name = 'aendret' AND tb.table_type = 'BASE TABLE'
  LOOP
    EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION saet_aendret()',
                   t || '_aendret', t);
  END LOOP;
END;
$$;
