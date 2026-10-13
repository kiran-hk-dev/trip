# Supabase setup

Everything in `supabase/` is **authored but has never been executed**. No
migration in this repository has been run against a real database, and no Edge
Function has been deployed. Treat this page as a plan, not a record of
success.

Work through it in order. The order matters.

---

## 1. Create the project

```bash
supabase login
supabase init
supabase link --project-ref <project-ref>
```

Then create `.env` at the repo root from `.env.example`. Only
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are needed for the client.

---

## 2. Turn off email confirmation

TripSplit has **no email-verification step**: signing up signs you straight in.

The app cannot change this itself. If your Supabase project still has email
confirmation on, Supabase refuses to issue a session, and sign-up will fail with
a message telling you so.

**Supabase dashboard → Authentication → Providers → Email → "Confirm email":
turn it OFF.**

After that, sign-up returns a session immediately and the user lands in the app.

If you ever do turn it on, the app still works — it just adds a step, and
sign-up falls back to signing the user in directly before giving up.

---

## 3. Secrets, and where they are allowed to live

This is the single most important rule in the project.

| Value | Where it may live | Where it must never go |
| --- | --- | --- |
| `SUPABASE_PUBLISHABLE_KEY` | `--dart-define`, client bundle | — |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Function secrets only | Flutter bundle, `.env` read by the app, logs |
| `AI_API_KEY` | Edge Function secrets only | anywhere the client can read |
| `EXCHANGE_RATE_API_KEY` | Edge Function secrets only | anywhere the client can read |
| `RESEND_API_KEY` | Edge Function secrets only | anywhere the client can read |

The service-role key bypasses every RLS policy in the database. If it leaks,
the database is wide open. If it ends up in a web bundle, it is in every
visitor's browser.

```bash
supabase secrets set AI_PROVIDER=openai AI_API_KEY=... AI_MODEL=...
supabase secrets set EXCHANGE_RATE_API_KEY=... EXCHANGE_RATE_PROVIDER=frankfurter
supabase secrets set RESEND_API_KEY=... EMAIL_FROM=...
```

---

## 4. Migrations

Eight migrations, in order:

| File | What it does |
| --- | --- |
| `0001_core_schema.sql` | Enums, tables, indexes, role helpers, `profiles` auto-create trigger |
| `0002_rls_policies.sql` | Row Level Security on every user and trip table |
| `0003_financial_functions.sql` | Largest-remainder allocation, `create_expense`, `trip_balances`, `suggest_settlements`, `record_settlement` |
| `0004_storage.sql` | Private buckets and `storage.objects` policies |
| `0005_reference_data.sql` | Emergency, visa and destination reference data |
| `0006_demo_seed.sql` | Fictional demo trip, users and expenses |
| `0007_function_grants.sql` | Explicit `GRANT EXECUTE` — the client's whole API surface |
| `0008_support_functions.sql` | Rate limiting, signed URLs, dashboard summary |

```bash
supabase db reset          # local: applies everything, then the seed
supabase db push           # remote: applies migrations not yet on the project
```

### Expect failures on the first run

They have never run. In particular, check these:

- **`0003` function signatures.** `0007` grants execute on exact argument
  lists. If a parameter in `0003` changes, every grant in `0007` silently fails
  to match and the RPC returns `permission denied for function`. If a Flutter
  call starts failing with a permissions error, look here first.
- **`0004` storage policies.** Bucket creation and `storage.objects` policies
  are order-sensitive and behave differently on a fresh project versus one
  where storage is already configured.
- **`0006` demo seed.** It depends on `0001`'s trigger having created the demo
  `profiles` rows, and it wraps the financial functions to bypass `auth.uid()`
  in a migration context. The wrappers are `SECURITY DEFINER` and are revoked
  again in `0007` — verify that revocation actually took effect.
- **Enums.** If `expense_category` or `settlement_method` gained a value in one
  migration and is used in another, the order matters.

### Verify RLS actually denies

Do not trust that the policies were created. Prove it:

```bash
# Signed in as a user who is NOT a member of this trip — expect zero rows.
supabase db exec "select count(*) from public.expenses where trip_id = '<trip-id>';"

# Anonymous — expect an empty set, not an error.
supabase db exec "set local role anon; select count(*) from public.expenses;"
```

```sql
-- From the app, as a member of one trip, try to read another trip's expenses.
-- This must return zero rows.
select * from public.expenses where trip_id = '<someone-elses-trip>';
```

If any of those return data, stop and fix the policies before shipping.

---

## 5. Reference data and verification states

`0005` seeds emergency contacts, guide content and visa links. Every row
carries `source_url`, `source_org`, `verification` and `last_checked`.

**Nothing is seeded as `verified`.** Nothing in this repository can prove a
phone number was correct when the app shipped, so claiming verification would
be a lie. The UI must keep showing the state and offering "open the official
source".

To promote a row, run `sync-resources` or a reviewed manual update, and record
the check in `source_verification_log`. Do not crowd-source. Do not add a
number you cannot trace to an official publisher. If a row cannot be verified,
leave it unverified or do not insert it — never substitute a guess.

---

## 6. Edge Functions

```bash
supabase functions deploy ai-itinerary
supabase functions deploy exchange-rates
supabase functions deploy invitations
supabase functions deploy notifications
supabase functions deploy sync-resources
```

Shared helpers live in `supabase/functions/_shared/mod.ts`.

None of these have been type checked or run. They import dependencies from
`jsr:` / `npm:` specifiers and expect Supabase environment variables that only
exist once deployed.

Things to check on first deploy:

- **`ai-itinerary`** must not accept arbitrary instructions from the client and
  must cap output size. Confirm the caller is authenticated and the trip is
  one they belong to.
- **`exchange-rates`** is a proxy to a third-party provider. It must use the
  service-role secret server-side and must rate limit. Never call the paid
  provider from the client, or the key is free to anyone who reads the bundle.
- **`invitations`** sends email. Confirm the sender domain is verified, or
  every invitation silently fails to deliver.
- **`notifications`** and **`sync-resources`** are scheduled, not user-facing.

Set `verify_jwt` deliberately per function. The emergency-facing read paths
want anonymous access; everything else must require a session.

---

## 7. Storage

All buckets are private. Downloads go through `create_signed_document_url` /
`create_signed_receipt_url` from `0008`, which authorise then sign. The client
never receives storage credentials and never receives a public URL.

Object paths are `<user_id>/<trip_id>/<uuid>.<ext>`. The first path segment is
the authorisation boundary and must equal `auth.uid()`. Check that the
`0004` policies actually enforce it rather than trusting the comment.

---

## 8. Before you call it done

- [ ] "Confirm email" is OFF in Auth > Providers > Email, so sign-up does not
      need a round trip through the inbox
- [ ] `supabase db reset` completes with no errors, locally
- [ ] `supabase db push` completes with no errors, on a real project
- [ ] Every table with user data has RLS enabled
- [ ] A non-member gets zero rows for someone else's trip
- [ ] `anon` gets zero rows for trip data
- [ ] The service-role key is absent from the built web bundle:
      `grep -r "service_role" build/web/`
- [ ] All five Edge Functions deploy and respond to a smoke test
- [ ] Rate limits are actually enforced
- [ ] Emergency contacts load anonymously, with no account