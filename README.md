# TripSplit World

Plan international trips, split expenses exactly, and stay reachable when
something goes wrong — on Android, iOS and the web.

Built with Flutter and Supabase (PostgreSQL + Row Level Security, Storage,
Realtime, Edge Functions).

---

## Status

Read this before you rely on anything below.

| Area | State |
| --- | --- |
| Financial engine (parsing, splitting, balances, settlements) | Complete and unit tested |
| Flutter UI across Android / iOS / Web | Complete, widget tested, builds for web |
| SQL migrations, RLS, storage policies | Authored, **never executed against a database** |
| Edge Functions | Authored, **never deployed or type checked** |
| Bundled emergency / visa data | Deliberately unverified, ships with sources |
| Android device run | Blocked locally (no Android SDK licences accepted) |
| iOS device run | Not attempted (requires macOS and a signing team) |

The parts marked **never executed** are the risky part. Nothing in this
repository has been proven to run against a real Supabase project. Do that
before building anything on top of it.

---

## Requirements

- Flutter `3.47.5` / Dart `3.13.4` (a recent stable SDK)
- Supabase CLI for the backend work: <https://supabase.com/docs/guides/cli>
- Chrome, for running the web target

Android and iOS toolchains are optional but needed for device builds.

---

## Running

```bash
flutter pub get
```

The app runs in **demo mode** with no Supabase project at all: fictional trips,
expenses, itineraries, packing lists and documents, driven through the same
financial engine as production, making no network calls.

```bash
flutter run --dart-define=DEMO_MODE=true
```

To run against a real Supabase project:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> \
  --dart-define=APP_ENV=development
```

Web build:

```bash
flutter build web --release   # -> build/web
```

### Configuration

`String.fromEnvironment` only reads values passed as `--dart-define`, so `.env`
files are not loaded automatically. Use `--dart-define` (as above) or your
platform's environment-to-define plumbing. Copy `.env.example` as a checklist
of every supported key.

**Never** put `SUPABASE_SERVICE_ROLE_KEY` in a `--dart-define` or in the
Flutter bundle. It bypasses every RLS policy. It belongs only in Edge Function
secrets. See [`docs/supabase.md`](docs/supabase.md).

---

## Architecture

```
lib/
  core/          money, theme, config
  data/          models, repositories, Supabase service, offline cache, demo fixtures
  features/      one directory per screen
  router/        go_router configuration and Riverpod providers
  shared/        design-system widgets
supabase/
  migrations/    schema, RLS, financial functions, storage, reference data, demo seed
  functions/     ai-itinerary, exchange-rates, invitations, notifications, sync-resources
```

### Money is never a float

Every amount is an `int` of **minor units** (cents, yen, satang) paired with an
ISO 4217 currency code. Floating point is never used to hold a value.

The amount a user actually paid is stored alongside the converted amount, and
the exchange rate and its timestamp are snapshotted at the moment of entry. A
rate change tomorrow must never silently restate last week's history.

### Splitting is exact

`lib/core/money/split_engine.dart` allocates using the **largest remainder**
method, distributing the leftover minor units one at a time so the parts always
sum to the original total. Equal, exact, percentage, shares, and weighted splits
are supported, and each expense records which method produced its shares so the
UI can explain them.

Settlements are computed by minimising transfers: match the largest debtor
against the largest creditor repeatedly instead of letting everyone pay
everyone.

### Access control lives in the database

Every table is under Row Level Security. The client never decides who may read
or write what; Postgres does. Money-touching writes go through
`SECURITY DEFINER` functions that re-check membership, so a compromised client
cannot forge a share.

### Demo data is obviously fictional

Trips are named for made-up places, people have placeholder names, and the seed
is marked as such. Nothing is presented as a real user or a real booking.

---

## Emergency and visa data: read this

The bundled emergency contacts, country guides and visa information are a
**starting point, not an authority**.

Every entry carries a source organisation, a source URL, a verification state
and a review date, and the UI shows all four. Nothing is labelled "Verified"
until a human has checked it against the official source. Where the app cannot
confirm something — your identity, whether an airline will board you, whether
your country maintains a consulate in Hong Kong — it says so rather than
guessing.

Not every country maintains a resident consulate in the Hong Kong SAR. The app
points you at your own foreign ministry's directory instead of inventing an
answer.

The whole Emergency Center works offline, with no account and no network.

---

## Tests

```bash
flutter analyze   # clean
flutter test      # 114 tests
```

| Suite | Covers |
| --- | --- |
| `test/core/money/` | parsing, formatting, every split method, balances, debt simplification |
| `test/features/emergency_data_test.dart` | bundled data integrity: sources, verification states, non-empty phrases |
| `test/features/emergency_pages_test.dart` | emergency screens render, never claim verification or guaranteed boarding, no overflow at 320px |
| `test/widgets/common_widgets_test.dart` | design system and responsive layout |

The emergency page tests deliberately use a tall viewport. Those screens are
long lazy lists, so asserting on a closing disclaimer from a phone-sized
viewport tests nothing unless the viewport is scrolled first — and scrolling is
flaky there, because total scroll extent is only known once the content below
the fold has been laid out. Layout regressions are still covered by separate
phone-sized and 320px-wide tests, which are the ones that catch an overflow.

---

## Not done yet

- Run the migrations against a real database and fix whatever breaks.
- Type check and deploy the Edge Functions.
- Accept the Android SDK licences and run on a device.
- Real emergency-data verification. Right now every entry says
  "Not yet verified", which is the honest state, not a bug.
- Push notifications and email are scaffolded but untested end to end.

## Documentation

- [`docs/supabase.md`](docs/supabase.md) — project setup, migrations, RLS,
  storage, Edge Functions, secrets
- [`docs/qa.md`](docs/qa.md) — manual test checklist for Android, iOS and web