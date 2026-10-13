// Applies the Supabase migrations to a real PostgreSQL (PGlite, WASM build)
// with minimal stand-ins for the `auth` and `storage` schemas that Supabase
// provides, so genuine parse + relation-resolution errors surface locally
// without needing Docker or a Supabase project.
//
// Usage:  node tool/apply_migrations.mjs [--verbose]

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PGlite } from "@electric-sql/pglite";

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = join(here, "..", "supabase", "migrations");
const verbose = process.argv.includes("--verbose");

// Stand-ins for the pieces Supabase injects. `auth.uid()` reads the same
// request GUC the real database uses, so RLS and SECURITY DEFINER functions
// behave the way they will in production.
//
// `anon`, `authenticated` and `service_role` are real Supabase roles. They are
// created empty here purely so GRANT statements resolve.
//
// Extensions are NOT available in this WASM build, so `create extension` lines
// are filtered out before execution. `gen_random_uuid()` is built into
// PostgreSQL 13+ and is supplied below as a fallback. This means the harness
// does not verify that the extensions you depend on exist on your project —
// check that separately on a real database.
const PRELUDE = `
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

create schema if not exists auth;
create schema if not exists storage;

create table if not exists auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text unique,
  raw_user_meta_data jsonb default '{}'::jsonb,
  created_at         timestamptz default now()
);

create table if not exists storage.buckets (
  id                 text primary key,
  name               text,
  public             boolean default false,
  file_size_limit    bigint,
  allowed_mime_types text[],
  created_at         timestamptz default now(),
  updated_at         timestamptz default now()
);

create table if not exists storage.objects (
  id         uuid primary key default gen_random_uuid(),
  bucket_id  text,
  name       text,
  owner      uuid,
  created_at timestamptz default now()
);

create or replace function auth.uid() returns uuid
  language sql stable as $fn$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $fn$;

create or replace function auth.email() returns text
  language sql stable as $fn$ select nullif(current_setting('request.jwt.claim.email', true), '') $fn$;

-- Supabase's auth.jwt() returns the decoded JWT claims as jsonb.
create or replace function auth.jwt() returns jsonb
  language sql stable as $fn$ select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb) $fn$;

-- pgcrypto is unavailable in this build; gen_random_uuid() is core in PG13+.
create or replace function public.gen_random_uuid() returns uuid
  language sql volatile as $fn$ select md5(random()::text || clock_timestamp()::text)::uuid $fn$;
`;

const db = new PGlite();
await db.exec(PRELUDE);

const files = readdirSync(migrationsDir).filter((f) => f.endsWith(".sql")).sort();
let failures = 0;

for (const file of files) {
  const raw = readFileSync(join(migrationsDir, file), "utf8");
  // Extensions are unavailable in the WASM build. Strip the statement so the
  // rest of the migration can still be verified.
  const sql = raw.replace(/^\s*create extension[^;]*;\s*$/gim, "");
  try {
    await db.exec(sql);
    console.log(`  ok    ${file}`);
  } catch (err) {
    failures += 1;
    console.log(`  FAIL  ${file}`);
    console.log(`        ${String(err.message).split("\n").slice(0, 6).join("\n        ")}`);
  }
}

if (verbose) {
  const { rows } = await db.query(`
    select tablename from pg_tables
    where schemaname = 'public' order by tablename`);
  console.log("\nTables created:");
  for (const r of rows) console.log(`  ${r.tablename}`);
  const { rows: fns } = await db.query(`
    select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' order by proname`);
  console.log(`\nFunctions created: ${fns.length}`);
}

console.log(`\n${files.length - failures}/${files.length} migrations applied`);
process.exit(failures ? 1 : 0);