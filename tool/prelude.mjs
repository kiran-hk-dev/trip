// Stand-ins for the pieces Supabase injects into a project database.
//
// `anon`, `authenticated` and `service_role` are real Supabase roles; they are
// created empty here purely so GRANT statements resolve.
//
// `auth.uid()` reads the same request GUC the real database uses, so RLS and
// SECURITY DEFINER functions behave the way they will in production.
//
// Extensions are NOT available in this WASM build, so migrations have their
// `create extension` statements stripped before execution and `gen_random_uuid()`
// is supplied directly (it is built into PostgreSQL 13+ anyway). This means the
// harness does not prove that the extensions you rely on exist on your project.
// Check that separately against a real database.

export const PRELUDE = `
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
  language sql stable as $fn$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $fn$;

create or replace function auth.email() returns text
  language sql stable as $fn$
    select nullif(current_setting('request.jwt.claim.email', true), '')
  $fn$;

create or replace function auth.jwt() returns jsonb
  language sql stable as $fn$
    select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb)
  $fn$;

create or replace function public.gen_random_uuid() returns uuid
  language sql volatile as $fn$
    select md5(random()::text || clock_timestamp()::text)::uuid
  $fn$;
`;