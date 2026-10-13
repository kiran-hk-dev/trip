// Executes the statements of one migration one at a time, reporting exactly
// which statement fails. Used to localise errors that file-level reporting
// cannot.
//
// Usage:  node tool/apply_one.mjs <migration-file>

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PGlite } from "@electric-sql/pglite";

const here = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS = join(here, "..", "supabase", "migrations");

import { pathToFileURL } from "node:url";
const { PRELUDE } = await import(pathToFileURL(join(here, "prelude.mjs")).href);

const file = process.argv[2];
if (!file) {
  console.error("usage: node tool/apply_one.mjs <migration-file>");
  process.exit(2);
}

const raw = readFileSync(join(MIGRATIONS, file), "utf8").replace(
  /^\s*create extension[^;]*;\s*$/gim,
  "",
);

// Split on statement boundaries the same way the server does: use the JSON
// emitted by tool/split_statements.py so splitting rules live in one place.
const statements = JSON.parse(
  readFileSync(join(MIGRATIONS, file.replace(/\.sql$/, ".stmts.json")), "utf8"),
);

const db = new PGlite();
await db.exec(PRELUDE);

// Apply every migration BEFORE the one under test, so the target file sees the
// same schema state it will have in a real `supabase db push`.
const files = readdirSync(MIGRATIONS).filter((f) => f.endsWith(".sql")).sort();
const before = files.slice(0, files.indexOf(file));
for (const f of before) {
  const sql = readFileSync(join(MIGRATIONS, f), "utf8").replace(
    /^\s*create extension[^;]*;\s*$/gim,
    "",
  );
  try {
    await db.exec(sql);
  } catch (err) {
    console.log(`(prerequisite ${f} failed: ${String(err.message).split("\n")[0]})`);
  }
}

console.log(`${file}: ${statements.length} statements, ${raw.split("\n").length} lines`);
console.log(`(applied ${before.length} prior migrations first)\n`);

let failed = 0;
for (let i = 0; i < statements.length; i++) {
  try {
    await db.exec(statements[i]);
    const head = statements[i].replace(/\s+/g, " ").slice(0, 70);
    console.log(`  ${String(i + 1).padStart(2)} ok    ${head}`);
  } catch (err) {
    failed += 1;
    const head = statements[i].replace(/\s+/g, " ").slice(0, 70);
    console.log(`  ${String(i + 1).padStart(2)} FAIL  ${head}`);
    console.log(`       ${String(err.message).split("\n").slice(0, 5).join("\n       ")}`);
  }
}

console.log(`\n${statements.length - failed}/${statements.length} statements applied`);
process.exit(failed ? 1 : 0);