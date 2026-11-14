# Ocab Alpha

Sagsstyring for Ocab i to dele, der deler samme data:

- **Ocab Alpha** – webapp til projektledere og ledere (PC og tablet): sager, økonomi, maskiner, biler, kort og rapporter.
- **Ocab Arbejdsordre** – mobilapp til sanitører og vagtledere: arbejdsordrer, timer, materialer, risikovurdering, billeder og rapporter. Virker uden net.

## Opbygning

Én Node.js-server ejer PostgreSQL-databasen og alle regler. De to apps taler kun med serveren.

```
server/          Node.js-server (TypeScript)
  db/migrations  Databasens tabeller, én fil pr. ændring
apps/            Ocab Alpha og Ocab Arbejdsordre (kommer)
docs/            Beslutninger og datamodel
```

## Kom i gang

Kræver Node.js 22 og PostgreSQL 16.

```bash
npm install
cp .env.example .env            # ret forbindelsen til databasen
npm run db:migrate --workspace server
npm test --workspace server     # kræver TEST_DATABASE_URL til en tom testdatabase
```
