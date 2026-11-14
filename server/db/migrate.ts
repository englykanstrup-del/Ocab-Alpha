// Kører databasemigreringer i rækkefølge. Hver fil køres kun én gang.
// Brug: DATABASE_URL=postgres://... npm run db:migrate
import { readdir, readFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const mappe = join(dirname(fileURLToPath(import.meta.url)), "migrations");

export async function migrer(databaseUrl: string): Promise<string[]> {
  const klient = new pg.Client({ connectionString: databaseUrl });
  await klient.connect();
  const koert: string[] = [];
  try {
    await klient.query(`
      CREATE TABLE IF NOT EXISTS skema_migrering (
        navn    text PRIMARY KEY,
        koert   timestamptz NOT NULL DEFAULT now()
      )`);
    const { rows } = await klient.query<{ navn: string }>("SELECT navn FROM skema_migrering");
    const allerede = new Set(rows.map((r) => r.navn));
    const filer = (await readdir(mappe)).filter((f) => f.endsWith(".sql")).sort();

    for (const fil of filer) {
      if (allerede.has(fil)) continue;
      const sql = await readFile(join(mappe, fil), "utf8");
      await klient.query("BEGIN");
      try {
        await klient.query(sql);
        await klient.query("INSERT INTO skema_migrering (navn) VALUES ($1)", [fil]);
        await klient.query("COMMIT");
        koert.push(fil);
      } catch (fejl) {
        await klient.query("ROLLBACK");
        throw new Error(`Migrering ${fil} fejlede: ${(fejl as Error).message}`);
      }
    }
  } finally {
    await klient.end();
  }
  return koert;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error("Sæt DATABASE_URL, fx postgres://ocab:ocab@localhost:5432/ocab");
    process.exit(1);
  }
  migrer(url)
    .then((koert) => {
      console.log(koert.length ? `Kørt: ${koert.join(", ")}` : "Databasen er allerede opdateret.");
    })
    .catch((fejl) => {
      console.error(fejl.message);
      process.exit(1);
    });
}
