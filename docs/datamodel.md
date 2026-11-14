# Datamodel

Godkendt 2026-11-14. Det fulde dokument med tegning og rettigheder ligger her:
https://claude.ai/artifact/BswDSaYFoyVEsJFjvGQDCZ

Tabellerne er skrevet i `server/db/migrations/001_grundlag.sql`, og startindholdet i de faste lister i `002_faste_lister.sql`.

## Valg truffet ved godkendelsen

- **Sagsnummer:** år og løbenummer, fx `2026-0142`.
- **Sagens status:** ny, aktiv, afventer, afsluttet, faktureret.
- **Skadetyper:** vand, brand, storm, skimmel, kloak, indbrud, andet.
- **Faggrupper på timer:** fra Master-prislisten 2026. Overtid er et flag på timen.
- **Rum på billeder:** frit tekstfelt.

## Faste regler

- Alle id'er er UUID, så Arbejdsordre kan oprette rækker uden net.
- `oprettet`, `aendret` og hvem der gjorde det gemmes på rækkerne. `aendret` opdateres automatisk.
- Intet slettes. Rækker arkiveres med `arkiveret_tid`.
- En maskine kan kun være opstillet ét sted ad gangen. Maskindøgn regnes i visningen `maskindoegn` (påbegyndte døgn tæller som hele).
- Rapportsvar gemmes ét pr. felt i `rapportfelt`, så de kan søges. Fugtmålinger og beboerlister har egne tabeller.

## Kommer i senere faser

Aftalekunder og prislister, tilbud, underleverandører, lager og lagerbevægelser, mails fra Outlook og eksport til Uniconta.
