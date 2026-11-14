-- 002_faste_lister.sql
-- Startindhold i de faste lister. Admin kan rette dem senere i Ocab Alpha.

INSERT INTO skadetype (kode, navn, raekkefolge) VALUES
  ('vand',     'Vand',     10),
  ('brand',    'Brand',    20),
  ('storm',    'Storm',    30),
  ('skimmel',  'Skimmel',  40),
  ('kloak',    'Kloak',    50),
  ('indbrud',  'Indbrud',  60),
  ('andet',    'Andet',    90);

-- Faggrupper fra Master-prislisten 2026. Overtid registreres som et flag på timen.
INSERT INTO faggruppe (kode, navn, raekkefolge) VALUES
  ('sanitoer',              'Sanitør',                     10),
  ('fugttekniker',          'Fugttekniker',                20),
  ('skimmeltekniker',       'Skimmeltekniker',             30),
  ('industritekniker',      'Industritekniker',            40),
  ('fagkonsulent',          'Fagkonsulent',                50),
  ('storskadeleder',        'Storskadeleder',              60),
  ('beredskabskonsulent',   'Beredskabskonsulent',         70),
  ('projektledelse',        'Projektledelse',              80),
  ('projektleder_special',  'Projektleder specialservice', 90),
  ('haandvaerkstaksering',  'Håndværkstaksering',         100);

-- Maskintyper med døgnpris fra Master-prislisten 2026
INSERT INTO maskintype (navn, kategori, doegnpris) VALUES
  ('Affugter',             'affugter',      237.00),
  ('Affugter speciel',     'affugter',      395.00),
  ('Kanalblæser',          'kanalblaeser',   81.15),
  ('Vandsuger',            'vandsuger',     277.50),
  ('Støvsuger',            'vandsuger',     125.00),
  ('Tæpperenser',          'andet',         625.00),
  ('Dykpumpe',             'dykpumpe',     125.00),
  ('Luftrenser',           'luftrenser',    187.50),
  ('Ozon',                 'ozon',          167.50),
  ('Hygrostat',            'andet',          43.75),
  ('Varmepanel stor',      'varme',         139.00),
  ('Varmepanel lille',     'varme',          55.00),
  ('Datalogger',           'andet',          27.00),
  ('Drymatic 1 boost',     'affugter',      395.00),
  ('Varmeblæser 2 kW',     'varme',          56.25),
  ('Varmeblæser 9 kW',     'varme',         300.00),
  ('Generator',            'andet',         250.00);

-- De fem rapporttyper. Felterne fyldes ind, når hver rapport bygges (Udkald og Fugt først).
INSERT INTO rapportskabelon (kode, version, navn) VALUES
  ('udkald',       1, 'Udkaldsrapport'),
  ('skafor',       1, 'SKAFOR-rapport'),
  ('besigtigelse', 1, 'Besigtigelsesrapport'),
  ('fugt',         1, 'Fugtrapport'),
  ('beboerliste',  1, 'Beboerliste');
