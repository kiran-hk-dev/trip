// Verifies the properties that matter and that applying the migrations does not
// prove on its own:
//
//   1. every GRANT in 0007 matches a function that actually exists
//   2. the impersonation wrappers are NOT executable by anon/authenticated
//   3. RLS actually denies a non-member (a policy that exists but does not
//      restrict is worse than no policy, because it looks correct)
//   4. the financial engine computes exact shares that sum to the total
//
// Usage:  node tool/verify_security.mjs

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { PGlite } from "@electric-sql/pglite";

const here = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS = join(here, "..", "supabase", "migrations");
const { PRELUDE } = await import(pathToFileURL(join(here, "prelude.mjs")).href);

const db = new PGlite();
await db.exec(PRELUDE);

for (const file of readdirSync(MIGRATIONS).filter((f) => f.endsWith(".sql")).sort()) {
  await db.exec(
    readFileSync(join(MIGRATIONS, file), "utf8").replace(
      /^\s*create extension[^;]*;\s*$/gim,
      "",
    ),
  );
}

let failures = 0;
function check(name, ok, detail = "") {
  console.log(`  ${ok ? "PASS" : "FAIL"}  ${name}${detail ? ` — ${detail}` : ""}`);
  if (!ok) failures += 1;
}

console.log("\n1. grants resolve to real functions");
const grants = await db.query(`
  select p.proname,
         pg_get_function_identity_arguments(p.oid) as args,
         has_function_privilege('authenticated', p.oid, 'execute') as auth_exec,
         has_function_privilege('anon', p.oid, 'execute')          as anon_exec
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'create_expense','update_expense','delete_expense','trip_balances',
      'suggest_settlements','record_settlement','budget_summary',
      'itinerary_conflicts','create_invitation','accept_invitation',
      'copy_template_list','export_my_data')
  order by p.proname`);
check(
  "all 12 client-callable functions exist and are executable by authenticated",
  grants.rows.length === 12 && grants.rows.every((r) => r.auth_exec),
  `${grants.rows.length}/12 found, executable: ${grants.rows.filter((r) => r.auth_exec).length}`,
);
for (const r of grants.rows.filter((x) => !x.auth_exec)) {
  console.log(`        not executable by authenticated: ${r.proname}(${r.args})`);
}

console.log("\n2. impersonation wrappers are closed to clients");
for (const fn of [
  "create_expense_internal",
  "record_settlement_internal",
  "create_expense_as",
  "record_settlement_as",
  "seed_demo_trip",
]) {
  const res = await db.query(
    `select p.oid::regprocedure::text as sig,
            has_function_privilege('authenticated', p.oid, 'execute') as auth_exec,
            has_function_privilege('anon', p.oid, 'execute') as anon_exec
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname='public' and p.proname = $1`,
    [fn],
  );
  const r = res.rows[0];
  check(
    `${fn} revoked from anon + authenticated`,
    !!r && !r.auth_exec && !r.anon_exec,
    r ? `auth=${r.auth_exec} anon=${r.anon_exec}` : "function not found",
  );
}

console.log("\n3. client-facing wrappers do NOT accept an impersonation GUC");
const src = await db.query(`
  select p.proname, pg_get_functiondef(p.oid) as def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname='public' and p.proname in ('create_expense','record_settlement')`);
for (const r of src.rows) {
  check(
    `${r.proname} does not read a seed/actor GUC`,
    !/app\.seed_actor|current_setting\(\s*'app\./i.test(r.def),
  );
}

console.log("\n4. RLS denies a non-member");
const ids = await db.query(`
  insert into auth.users (id, email) values
    (gen_random_uuid(), 'owner@example.test'),
    (gen_random_uuid(), 'outsider@example.test')
  returning id, email`);
const owner = ids.rows.find((r) => r.email === "owner@example.test").id;
const outsider = ids.rows.find((r) => r.email === "outsider@example.test").id;

const trip = await db.query(
  `insert into public.trips (owner_id, name, start_date, end_date)
   values ($1, 'RLS probe trip', current_date, current_date + 2) returning id`,
  [owner],
);
const tripId = trip.rows[0].id;

await db.exec(`set role authenticated; set request.jwt.claim.sub = '${owner}';`);
const asOwner = await db.query(
  `select count(*)::int as n from public.trips where id = '${tripId}'`,
);
check("owner can read own trip", asOwner.rows[0].n === 1);

await db.exec(`set request.jwt.claim.sub = '${outsider}';`);
const asOutsider = await db.query(
  `select count(*)::int as n from public.trips where id = '${tripId}'`,
);
check("non-member gets zero rows", asOutsider.rows[0].n === 0, `got ${asOutsider.rows[0].n}`);

const anonRead = await db.query(`select count(*)::int as n from public.trips`);
check("authenticated cannot read other people's trips", anonRead.rows[0].n === 0);

await db.exec(`set role anon;`);
// anon has no SELECT grant on trips at all, so the database refuses the query
// outright rather than returning rows. Either outcome is safe; an error is the
// stronger guarantee. Record which one happened rather than assuming.
let anonDenied = false;
let anonDetail = "";
try {
  const r = await db.query(`select count(*)::int as n from public.trips`);
  anonDenied = r.rows[0].n === 0;
  anonDetail = `returned ${r.rows[0].n} rows`;
} catch (err) {
  anonDenied = true;
  anonDetail = `refused: ${err.message}`;
}
check("anon cannot read trip data", anonDenied, anonDetail);

const anonEmergency = await db.query(
  `select count(*)::int as n from public.emergency_resources`,
);
check(
  "anon CAN read emergency reference data (offline-first requirement)",
  anonEmergency.rows[0].n > 0,
  `${anonEmergency.rows[0].n} rows`,
);
await db.exec(`reset role;`);

console.log("\n5. financial engine allocates exactly");
const alloc = await db.query(`
  select public.allocate_minor(10000::bigint, array[1,1,1]::bigint[]) as three_way,
         public.allocate_minor(100::bigint,   array[1,1,1,1,1,1,1]::bigint[]) as seven_way,
         public.allocate_minor(1::bigint,     array[1,1]::bigint[]) as one_cent`);
check(
  "100.00 split 3 ways sums to 10000 with no cent created or lost",
  alloc.rows[0].three_way.reduce((a, b) => a + Number(b), 0) === 10000,
  JSON.stringify(alloc.rows[0].three_way),
);
check(
  "100 cents split 7 ways sums to exactly 100",
  alloc.rows[0].seven_way.reduce((a, b) => a + Number(b), 0) === 100,
  JSON.stringify(alloc.rows[0].seven_way),
);
check(
  "1 cent split 2 ways still sums to 1 (zero-share edge case)",
  alloc.rows[0].one_cent.reduce((a, b) => a + Number(b), 0) === 1,
  JSON.stringify(alloc.rows[0].one_cent),
);

console.log(`\n${failures === 0 ? "ALL CHECKS PASSED" : `${failures} CHECK(S) FAILED`}`);
process.exit(failures ? 1 : 0);