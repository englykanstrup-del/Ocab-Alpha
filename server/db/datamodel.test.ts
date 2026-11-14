// Tester datamodellen mod en rigtig PostgreSQL.
// Kræver TEST_DATABASE_URL til en tom testdatabase.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import pg from "pg";
import { migrer } from "./migrate.ts";

const url = process.env.TEST_DATABASE_URL;
const db = new pg.Client({ connectionString: url });

before(async () => {
  if (!url) throw new Error("Sæt TEST_DATABASE_URL");
  await db.connect();
  await db.query("DROP SCHEMA public CASCADE; CREATE SCHEMA public;");
  await migrer(url);
});
after(() => db.end());

async function nyMedarbejder(rolle = "sanitoer") {
  const { rows } = await db.query(
    "INSERT INTO medarbejder (navn, rolle, postnummer) VALUES ('Test', $1, '8000') RETURNING id",
    [rolle],
  );
  return rows[0].id as string;
}

async function nySag() {
  const { rows } = await db.query(
    "INSERT INTO sag (skadeadresse, skadetype) VALUES ('Testvej 1, 8000 Aarhus C', 'vand') RETURNING id, sagsnummer",
  );
  return rows[0] as { id: string; sagsnummer: string };
}

test("migreringer kan køres igen uden at gøre noget", async () => {
  assert.deepEqual(await migrer(url!), []);
});

test("sagsnummer er år og løbenummer", async () => {
  const a = await nySag();
  const b = await nySag();
  const aar = new Date().getFullYear();
  assert.match(a.sagsnummer, new RegExp(`^${aar}-\\d{4}$`));
  assert.equal(Number(b.sagsnummer.slice(5)), Number(a.sagsnummer.slice(5)) + 1);
});

test("faste lister er fyldt ud", async () => {
  const tael = async (t: string) => Number((await db.query(`SELECT count(*) FROM ${t}`)).rows[0].count);
  assert.equal(await tael("skadetype"), 7);
  assert.equal(await tael("faggruppe"), 10);
  assert.equal(await tael("rapportskabelon"), 5);
  assert.ok((await tael("maskintype")) > 10);
});

test("en maskine kan kun stå på én sag ad gangen", async () => {
  const sag1 = await nySag();
  const sag2 = await nySag();
  const type = (await db.query("SELECT id FROM maskintype LIMIT 1")).rows[0].id;
  const m = (
    await db.query("INSERT INTO maskine (nummer, qr_kode, maskintype_id) VALUES ('A-001', 'QR-A-001', $1) RETURNING id", [type])
  ).rows[0].id;
  await db.query("INSERT INTO opstilling (maskine_id, sag_id) VALUES ($1, $2)", [m, sag1.id]);
  await assert.rejects(db.query("INSERT INTO opstilling (maskine_id, sag_id) VALUES ($1, $2)", [m, sag2.id]));
  await db.query("UPDATE opstilling SET nedtaget_tid = now() WHERE maskine_id = $1", [m]);
  await db.query("INSERT INTO opstilling (maskine_id, sag_id) VALUES ($1, $2)", [m, sag2.id]);
});

test("maskindøgn tæller påbegyndte døgn", async () => {
  const sag = await nySag();
  const type = (await db.query("SELECT id FROM maskintype LIMIT 1")).rows[0].id;
  const m = (
    await db.query("INSERT INTO maskine (nummer, qr_kode, maskintype_id) VALUES ('A-002', 'QR-A-002', $1) RETURNING id", [type])
  ).rows[0].id;
  await db.query(
    "INSERT INTO opstilling (maskine_id, sag_id, opsat_tid, nedtaget_tid) VALUES ($1, $2, now() - interval '50 hours', now())",
    [m, sag.id],
  );
  const { rows } = await db.query("SELECT doegn FROM maskindoegn WHERE maskine_id = $1", [m]);
  assert.equal(rows[0].doegn, 3);
});

test("afvist ordre kræver en grund", async () => {
  const sag = await nySag();
  const med = await nyMedarbejder();
  const ordre = (await db.query("INSERT INTO arbejdsordre (sag_id, type) VALUES ($1, 'udkald') RETURNING id", [sag.id])).rows[0].id;
  await assert.rejects(
    db.query("INSERT INTO ordre_deltager (arbejdsordre_id, medarbejder_id, svar) VALUES ($1, $2, 'afvist')", [ordre, med]),
  );
  await db.query(
    "INSERT INTO ordre_deltager (arbejdsordre_id, medarbejder_id, svar, afvist_grund) VALUES ($1, $2, 'afvist', 'Kan ikke tage den')",
    [ordre, med],
  );
});

test("timer skal have en kendt faggruppe og være mellem 0 og 24", async () => {
  const sag = await nySag();
  const med = await nyMedarbejder();
  const ordre = (await db.query("INSERT INTO arbejdsordre (sag_id, type) VALUES ($1, 'opstart') RETURNING id", [sag.id])).rows[0].id;
  const indsaet = (timer: number, fag: string) =>
    db.query(
      "INSERT INTO timeregistrering (arbejdsordre_id, medarbejder_id, dato, timer, faggruppe) VALUES ($1, $2, current_date, $3, $4)",
      [ordre, med, timer, fag],
    );
  await indsaet(7.5, "sanitoer");
  await assert.rejects(indsaet(25, "sanitoer"));
  await assert.rejects(indsaet(2, "ukendt"));
});

test("aendret opdateres automatisk", async () => {
  const sag = await nySag();
  const foer = (await db.query("SELECT aendret FROM sag WHERE id = $1", [sag.id])).rows[0].aendret;
  await new Promise((r) => setTimeout(r, 20));
  await db.query("UPDATE sag SET status = 'aktiv' WHERE id = $1", [sag.id]);
  const efter = (await db.query("SELECT aendret FROM sag WHERE id = $1", [sag.id])).rows[0].aendret;
  assert.ok(efter > foer);
});

test("rapportsvar gemmes pr. felt og kan søges", async () => {
  const sag = await nySag();
  const rap = (
    await db.query(
      "INSERT INTO rapport (sag_id, skabelon_kode, skabelon_version) VALUES ($1, 'fugt', 1) RETURNING id",
      [sag.id],
    )
  ).rows[0].id;
  await db.query("INSERT INTO rapportfelt (rapport_id, felt, vaerdi) VALUES ($1, 'aarsag', 'Utæt rør under køkkenvask')", [rap]);
  const { rows } = await db.query("SELECT rapport_id FROM rapportfelt WHERE vaerdi ILIKE '%køkkenvask%'");
  assert.equal(rows[0].rapport_id, rap);
});
