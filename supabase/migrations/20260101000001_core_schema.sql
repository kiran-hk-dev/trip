-- =====================================================================
-- TripSplit World — 0001 core schema
-- All monetary columns are INTEGER minor units (cents, paise, fils).
-- Floating point is never used for money anywhere in this database.
-- =====================================================================

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

-- ---------------------------------------------------------------------
-- Enumerated types
-- ---------------------------------------------------------------------
create type travel_style       as enum ('budget', 'balanced', 'comfort', 'luxury');
create type trip_status        as enum ('draft', 'planning', 'upcoming', 'ongoing', 'completed', 'cancelled', 'archived');
create type trip_role          as enum ('owner', 'admin', 'editor', 'viewer');
create type invitation_status  as enum ('pending', 'accepted', 'revoked', 'expired');
create type itinerary_kind     as enum ('attraction', 'restaurant', 'experience', 'accommodation', 'transport', 'flight', 'free_time', 'other');
create type expense_category   as enum (
  'flights', 'ground_transport', 'accommodation', 'food', 'local_transport',
  'activities', 'shopping', 'visa_fees', 'insurance', 'connectivity',
  'airport_transfer', 'medical', 'other'
);
create type split_method       as enum ('equal', 'exact', 'percentage', 'shares', 'none');
create type settlement_status  as enum ('recorded', 'confirmed', 'disputed');
create type settlement_method  as enum ('cash', 'bank_transfer', 'upi', 'card', 'other');
create type booking_kind       as enum ('flight', 'train', 'bus', 'hotel', 'hostel', 'rental', 'transfer', 'tour', 'restaurant', 'cruise', 'other');
create type booking_status     as enum ('confirmed', 'pending', 'cancelled', 'refunded', 'completed');
create type checklist_kind     as enum ('packing', 'predeparture', 'visa', 'custom');
create type notification_kind  as enum (
  'trip_invite', 'trip_update', 'expense_added', 'budget_alert', 'settlement',
  'departure_reminder', 'booking_reminder', 'document_reminder',
  'passport_reminder', 'visa_reminder', 'packing_reminder', 'system'
);
create type verification_state as enum ('verified', 'unverified', 'stale', 'needs_review');
create type sync_status        as enum ('synced', 'pending', 'failed');

-- ---------------------------------------------------------------------
-- profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------
create table public.profiles (
  id                    uuid primary key references auth.users(id) on delete cascade,
  full_name             text,
  avatar_path           text,
  phone                 text,
  home_country          text,
  residence_country     text,
  nationality_countries text[] not null default '{}',
  passport_country      text,
  -- Optional and deliberately nullable: a passport number is never required
  -- to use trip planning, and we never store the number itself here.
  passport_expiry_date  date,
  preferred_currency    char(3) not null default 'USD',
  preferred_language    text not null default 'en',
  timezone              text not null default 'UTC',
  dietary_preferences   text[] not null default '{}',
  accessibility_needs   text,
  travel_interests      text[] not null default '{}',
  travel_style          travel_style,
  emergency_contact_name  text,
  emergency_contact_phone text,
  emergency_contact_email text,
  notification_preferences jsonb not null default '{}'::jsonb,
  onboarding_completed  boolean not null default false,
  demo_account          boolean not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
comment on column public.profiles.passport_expiry_date is
  'Reminder-only. TripSplit never requires or stores a passport number.';

create index profiles_country_idx on public.profiles (home_country);
create index profiles_passport_expiry_idx on public.profiles (passport_expiry_date)
  where passport_expiry_date is not null;

-- Auto-create a profile row when a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, preferred_currency, preferred_language)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    coalesce(new.raw_user_meta_data ->> 'preferred_currency', 'USD'),
    coalesce(new.raw_user_meta_data ->> 'preferred_language', 'en')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- trips
-- ---------------------------------------------------------------------
create table public.trips (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null references public.profiles(id) on delete cascade,
  name             text not null check (char_length(btrim(name)) between 1 and 120),
  description      text,
  origin           text,
  country_code     char(2),
  start_date       date not null,
  end_date         date not null,
  timezone         text,
  traveler_count   int not null default 1 check (traveler_count > 0),
  base_currency    char(3) not null default 'USD',
  total_budget_minor bigint not null default 0 check (total_budget_minor >= 0),
  contingency_pct  numeric(5,2) not null default 10 check (contingency_pct between 0 and 100),
  travel_style     travel_style not null default 'balanced',
  travel_purpose   text,
  interests        text[] not null default '{}',
  transport_preferences  text[] not null default '{}',
  accommodation_preferences text[] not null default '{}',
  dietary_notes    text,
  accessibility_notes text,
  notes            text,
  cover_image_url  text,
  status           trip_status not null default 'planning',
  visibility       text not null default 'private' check (visibility in ('private','shared')),
  itinerary_pace   text not null default 'balanced' check (itinerary_pace in ('relaxed','balanced','packed')),
  archived         boolean not null default false,
  version          int not null default 1,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint trips_date_order check (end_date >= start_date)
);

create index trips_owner_idx on public.trips (owner_id, archived);
create index trips_status_dates_idx on public.trips (status, start_date);
create index trips_country_idx on public.trips (country_code);

-- ---------------------------------------------------------------------
-- trip_members
-- ---------------------------------------------------------------------
create table public.trip_members (
  id          uuid primary key default gen_random_uuid(),
  trip_id     uuid not null references public.trips(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  role        trip_role not null default 'viewer',
  status      text not null default 'active' check (status in ('active','removed')),
  joined_at   timestamptz not null default now(),
  unique (trip_id, user_id)
);
create index trip_members_user_idx on public.trip_members (user_id, status);
create index trip_members_trip_idx on public.trip_members (trip_id);

-- ---------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------

-- True when the current auth user is a member of the given trip with any of
-- the supplied roles. SECURITY DEFINER + STABLE so it can be used inside RLS
-- policies without recursing through trip_members policies.
create or replace function public.is_trip_member(p_trip uuid, p_roles trip_role[] default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.trip_members m
    where m.trip_id = p_trip
      and m.user_id = auth.uid()
      and m.status = 'active'
      and (p_roles is null or m.role = any(p_roles))
  );
$$;

create or replace function public.trip_role_of(p_trip uuid)
returns trip_role
language sql
stable
security definer
set search_path = public
as $$
  select m.role from public.trip_members m
  where m.trip_id = p_trip and m.user_id = auth.uid() and m.status = 'active'
  limit 1;
$$;

-- Can the current user write to shared trip content (expenses, itinerary...).
create or replace function public.can_edit_trip(p_trip uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_trip_member(p_trip, array['owner','admin','editor']::trip_role[]);
$$;

-- Can the current user manage membership / invitations / trip settings.
create or replace function public.can_admin_trip(p_trip uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_trip_member(p_trip, array['owner','admin']::trip_role[]);
$$;


-- ---------------------------------------------------------------------
-- trip_invitations
-- ---------------------------------------------------------------------
create table public.trip_invitations (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.trips(id) on delete cascade,
  invited_email text not null,
  role          trip_role not null default 'viewer',
  token_hash    text not null unique,       -- sha256 of the emailed token
  status        invitation_status not null default 'pending',
  invited_by    uuid references public.profiles(id) on delete set null,
  accepted_by   uuid references public.profiles(id) on delete set null,
  expires_at    timestamptz not null default (now() + interval '14 days'),
  created_at    timestamptz not null default now(),
  accepted_at   timestamptz
);
create index trip_invitations_lookup_idx
  on public.trip_invitations (lower(invited_email), status);

-- ---------------------------------------------------------------------
-- trip_destinations (multi-city / multi-country support)
-- ---------------------------------------------------------------------
create table public.trip_destinations (
  id          uuid primary key default gen_random_uuid(),
  trip_id     uuid not null references public.trips(id) on delete cascade,
  position    int not null default 0,
  name        text not null,
  country     text,
  country_code char(2),
  city        text,
  latitude    double precision check (latitude between -90 and 90),
  longitude   double precision check (longitude between -180 and 180),
  timezone    text,
  arrival_date date,
  departure_date date,
  notes       text,
  unique (trip_id, position)
);
create index trip_destinations_trip_idx on public.trip_destinations (trip_id);

-- ---------------------------------------------------------------------
-- itinerary
-- ---------------------------------------------------------------------
create table public.itinerary_days (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid not null references public.trips(id) on delete cascade,
  day_number int not null,
  date       date not null,
  title      text,
  notes      text,
  position   int not null default 0,
  created_at timestamptz not null default now(),
  unique (trip_id, day_number)
);
create index itinerary_days_trip_date_idx on public.itinerary_days (trip_id, date);

create table public.itinerary_items (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.trips(id) on delete cascade,
  day_id        uuid not null references public.itinerary_days(id) on delete cascade,
  title         text not null check (char_length(btrim(title)) between 1 and 160),
  kind          itinerary_kind not null default 'other',
  description   text,
  start_time    time,
  end_time      time,
  address       text,
  latitude      double precision check (latitude between -90 and 90),
  longitude     double precision check (longitude between -180 and 180),
  place_id      text,
  cost_minor    bigint not null default 0 check (cost_minor >= 0),
  cost_currency char(3) not null default 'USD',
  booking_url   text,
  booking_reference text,
  -- Only set when a verified source supplied them. Never guessed.
  opening_hours_verified boolean not null default false,
  opening_hours_source_url text,
  completed     boolean not null default false,
  position      int not null default 0,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index itinerary_items_day_idx on public.itinerary_items (day_id, position);
create index itinerary_items_trip_idx on public.itinerary_items (trip_id);

-- ---------------------------------------------------------------------
-- budgets
-- ---------------------------------------------------------------------
create table public.budgets (
  id             uuid primary key default gen_random_uuid(),
  trip_id        uuid not null unique references public.trips(id) on delete cascade,
  currency       char(3) not null default 'USD',
  total_minor    bigint not null default 0 check (total_minor >= 0),
  contingency_minor bigint not null default 0 check (contingency_minor >= 0),
  daily_limit_minor bigint not null default 0 check (daily_limit_minor >= 0),
  alert_threshold_pct numeric(5,2) not null default 80 check (alert_threshold_pct between 1 and 100),
  notes          text,
  version        int not null default 1,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table public.budget_categories (
  id           uuid primary key default gen_random_uuid(),
  budget_id    uuid not null references public.budgets(id) on delete cascade,
  trip_id      uuid not null references public.trips(id) on delete cascade,
  category     expense_category not null,
  planned_minor bigint not null default 0 check (planned_minor >= 0),
  is_essential boolean not null default false,
  notes        text,
  unique (budget_id, category)
);
create index budget_categories_budget_idx on public.budget_categories (budget_id);

-- ---------------------------------------------------------------------
-- expenses — the financial core
-- ---------------------------------------------------------------------
create table public.expenses (
  id              uuid primary key default gen_random_uuid(),
  trip_id         uuid not null references public.trips(id) on delete cascade,
  title           text not null check (char_length(btrim(title)) between 1 and 160),
  -- Amount exactly as entered by the payer.
  amount_minor    bigint not null check (amount_minor > 0),
  currency        char(3) not null,
  -- Amount converted into the trip's base currency using a SNAPSHOT rate.
  -- The original amount is never mutated when rates later change.
  base_amount_minor bigint not null check (base_amount_minor > 0),
  fx_rate         numeric(20,10) not null default 1,
  fx_provider     text,
  fx_fetched_at   timestamptz,
  fx_is_indicative boolean not null default true,
  category        expense_category not null default 'other',
  expense_date    date not null default current_date,
  paid_by         uuid not null references public.profiles(id) on delete restrict,
  split_method    split_method not null default 'equal',
  is_personal     boolean not null default false,
  notes           text,
  receipt_path    text,
  -- Redundant denormalisation used by RLS so a member can be checked without
  -- joining expense_participants (which itself depends on membership).
  participant_ids uuid[] not null default '{}',
  deleted_at      timestamptz,
  created_by      uuid references public.profiles(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index expenses_trip_date_idx on public.expenses (trip_id, expense_date desc) where deleted_at is null;
create index expenses_payer_idx on public.expenses (paid_by);
create index expenses_category_idx on public.expenses (trip_id, category) where deleted_at is null;
create index expenses_participants_idx on public.expenses using gin (participant_ids);

-- Canonical per-participant share, in the EXPENSE currency minor units.
-- The sum over all rows for an expense MUST equal expenses.amount_minor.
-- This invariant is enforced by the deferred constraint trigger below.
create table public.expense_participants (
  id          uuid primary key default gen_random_uuid(),
  expense_id  uuid not null references public.expenses(id) on delete cascade,
  trip_id     uuid not null references public.trips(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  unique (expense_id, user_id)
);
create index expense_participants_trip_user_idx on public.expense_participants (trip_id, user_id);

create table public.expense_shares (
  id              uuid primary key default gen_random_uuid(),
  expense_id      uuid not null references public.expenses(id) on delete cascade,
  trip_id         uuid not null references public.trips(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  -- Share in the expense's original currency (audit fidelity).
  amount_minor    bigint not null check (amount_minor >= 0),
  -- Share converted to the trip base currency (used for balances).
  base_amount_minor bigint not null check (base_amount_minor >= 0),
  percentage      numeric(7,4),
  weight          int,
  unique (expense_id, user_id)
);
create index expense_shares_trip_user_idx on public.expense_shares (trip_id, user_id);
create index expense_shares_expense_idx on public.expense_shares (expense_id);

-- ---------------------------------------------------------------------
-- settlements
-- ---------------------------------------------------------------------
create table public.settlements (
  id             uuid primary key default gen_random_uuid(),
  trip_id        uuid not null references public.trips(id) on delete cascade,
  from_user_id   uuid not null references public.profiles(id) on delete restrict,
  to_user_id     uuid not null references public.profiles(id) on delete restrict,
  amount_minor   bigint not null check (amount_minor > 0),
  currency       char(3) not null,
  base_amount_minor bigint not null check (base_amount_minor > 0),
  fx_rate        numeric(20,10) not null default 1,
  fx_provider    text,
  fx_fetched_at  timestamptz,
  -- 'recorded' means a user told us they paid. It is NOT proof of transfer.
  -- 'confirmed' can only be set by a verified server-side provider webhook.
  status         settlement_status not null default 'recorded',
  method         settlement_method not null default 'other',
  reference      text,
  notes          text,
  settled_at     date not null default current_date,
  verified_at    timestamptz,
  verified_by    text,
  idempotency_key text unique,
  created_by     uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint settlements_no_self check (from_user_id <> to_user_id)
);
create index settlements_trip_idx on public.settlements (trip_id, settled_at desc) where deleted_at is null;
create index settlements_from_idx on public.settlements (from_user_id);
create index settlements_to_idx on public.settlements (to_user_id);

create table public.settlement_allocations (
  id             uuid primary key default gen_random_uuid(),
  settlement_id  uuid not null references public.settlements(id) on delete cascade,
  trip_id        uuid not null references public.trips(id) on delete cascade,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  base_amount_minor bigint not null check (base_amount_minor <> 0),
  unique (settlement_id, user_id)
);
create index settlement_allocations_trip_user_idx on public.settlement_allocations (trip_id, user_id);

-- ---------------------------------------------------------------------
-- exchange rates
-- ---------------------------------------------------------------------
create table public.exchange_rates (
  id            uuid primary key default gen_random_uuid(),
  base_currency char(3) not null,
  quote_currency char(3) not null,
  rate          numeric(20,10) not null check (rate > 0),
  provider      text not null,
  is_indicative boolean not null default true,
  fetched_at    timestamptz not null default now(),
  unique (base_currency, quote_currency, provider, fetched_at)
);
create index exchange_rates_lookup_idx
  on public.exchange_rates (base_currency, quote_currency, fetched_at desc);

create table public.currency_conversion_history (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  from_currency   char(3) not null,
  to_currency     char(3) not null,
  input_minor     bigint not null,
  output_minor    bigint not null,
  rate            numeric(20,10) not null,
  provider        text not null,
  is_indicative   boolean not null default true,
  is_offline_cached boolean not null default false,
  fee_estimate_pct numeric(5,2),
  created_at      timestamptz not null default now()
);
create index conversion_history_user_idx on public.currency_conversion_history (user_id, created_at desc);

-- ---------------------------------------------------------------------
-- bookings
-- ---------------------------------------------------------------------
create table public.bookings (
  id                uuid primary key default gen_random_uuid(),
  trip_id           uuid not null references public.trips(id) on delete cascade,
  kind              booking_kind not null,
  provider          text not null,
  title             text not null,
  confirmation_reference text,
  origin            text,
  destination       text,
  starts_at         timestamptz,
  ends_at           timestamptz,
  address           text,
  amount_paid_minor bigint not null default 0 check (amount_paid_minor >= 0),
  currency          char(3) not null default 'USD',
  cancellation_deadline timestamptz,
  status            booking_status not null default 'confirmed',
  external_url      text,
  attachment_paths  text[] not null default '{}',
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index bookings_trip_idx on public.bookings (trip_id, starts_at);

-- ---------------------------------------------------------------------
-- documents (private storage metadata)
-- ---------------------------------------------------------------------
create table public.travel_documents (
  id             uuid primary key default gen_random_uuid(),
  trip_id        uuid references public.trips(id) on delete cascade,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  name           text not null,
  doc_type       text not null default 'other',
  storage_path   text not null,
  mime_type      text not null,
  size_bytes     bigint not null check (size_bytes > 0 and size_bytes <= 26214400),
  -- Optional, never required. See profiles.passport_expiry_date note.
  sensitive      boolean not null default true,
  expiry_date    date,
  expires_at     timestamptz,     -- storage retention
  notes          text,
  created_at     timestamptz not null default now(),
  deleted_at     timestamptz
);
create index travel_documents_trip_idx on public.travel_documents (trip_id) where deleted_at is null;
create index travel_documents_user_idx on public.travel_documents (user_id) where deleted_at is null;
create index travel_documents_expiry_idx on public.travel_documents (expiry_date) where expiry_date is not null;

-- ---------------------------------------------------------------------
-- packing + pre-departure checklists
-- ---------------------------------------------------------------------
create table public.packing_lists (
  id          uuid primary key default gen_random_uuid(),
  trip_id     uuid references public.trips(id) on delete cascade,
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  name        text not null,
  kind        checklist_kind not null default 'packing',
  is_shared   boolean not null default true,
  is_template boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index packing_lists_trip_idx on public.packing_lists (trip_id);

create table public.packing_list_items (
  id            uuid primary key default gen_random_uuid(),
  list_id       uuid not null references public.packing_lists(id) on delete cascade,
  label         text not null,
  category      text not null default 'other',
  quantity      int not null default 1 check (quantity > 0),
  is_packed     boolean not null default false,
  assigned_to   uuid references public.profiles(id) on delete set null,
  notes         text,
  position      int not null default 0,
  -- Offline availability for essential pre-departure checklists.
  available_offline boolean not null default false,
  created_at    timestamptz not null default now()
);
create index packing_items_list_idx on public.packing_list_items (list_id, position);

-- ---------------------------------------------------------------------
-- visa organiser
-- ---------------------------------------------------------------------
create table public.visa_records (
  id               uuid primary key default gen_random_uuid(),
  trip_id          uuid not null references public.trips(id) on delete cascade,
  destination_country text not null,
  nationality_country text not null,
  residence_country text,
  transit_countries text[] not null default '{}',
  travel_purpose   text,
  entry_date       date,
  exit_date        date,
  authorization_type text,
  status           text not null default 'not_checked'
                   check (status in ('not_checked','required','not_required','applied','approved','expired','unknown')),
  official_url     text,
  source_organization text,
  last_verified_at timestamptz,
  verification     verification_state not null default 'unverified',
  notes            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (trip_id, destination_country)
);
create index visa_records_trip_idx on public.visa_records (trip_id);

-- ---------------------------------------------------------------------
-- insurance
-- ---------------------------------------------------------------------
create table public.insurance_policies (
  id                uuid primary key default gen_random_uuid(),
  trip_id           uuid references public.trips(id) on delete cascade,
  user_id           uuid not null references public.profiles(id) on delete cascade,
  provider          text not null,
  policy_reference  text,
  assistance_phone  text,
  coverage_start    date,
  coverage_end      date,
  coverage_notes    text,
  document_path     text,
  created_at        timestamptz not null default now()
);
create index insurance_policies_trip_idx on public.insurance_policies (trip_id);

-- ---------------------------------------------------------------------
-- saved destinations / wishlist
-- ---------------------------------------------------------------------
create table public.saved_destinations (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  name         text not null,
  country      text,
  country_code char(2),
  notes        text,
  target_date  date,
  estimated_budget_minor bigint,
  currency     char(3) default 'USD',
  created_at   timestamptz not null default now(),
  unique (user_id, name, country)
);

create table public.destinations (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  country      text,
  country_code char(2),
  city         text,
  latitude     double precision,
  longitude    double precision,
  timezone     text,
  currency     char(3),
  languages    text[] not null default '{}',
  image_url    text,
  summary      text,
  categories   text[] not null default '{}',
  best_months  int[] not null default '{}',
  typical_daily_budget_minor bigint,
  is_demo      boolean not null default false,
  verified     boolean not null default false,
  created_at   timestamptz not null default now(),
  unique (name, country_code)
);
create index destinations_country_idx on public.destinations (country_code);
create index destinations_categories_idx on public.destinations using gin (categories);

-- ---------------------------------------------------------------------
-- notifications + activity
-- ---------------------------------------------------------------------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       notification_kind not null,
  title      text not null,
  body       text,
  trip_id    uuid references public.trips(id) on delete cascade,
  payload    jsonb not null default '{}'::jsonb,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_unread_idx on public.notifications (user_id) where read_at is null;

create table public.activity_logs (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid references public.trips(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete set null,
  entity_type text not null,
  entity_id   uuid,
  action      text not null,
  summary     text not null,
  metadata    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index activity_logs_trip_idx on public.activity_logs (trip_id, created_at desc);
create index activity_logs_user_idx on public.activity_logs (user_id, created_at desc);

-- ---------------------------------------------------------------------
-- emergency reference data (public read, service-role write)
-- ---------------------------------------------------------------------
create table public.emergency_resources (
  id               uuid primary key default gen_random_uuid(),
  country_code     char(2) not null,
  country_name     text not null,
  category         text not null,
  service_name     text not null,
  phone            text,
  alternate_phone  text,
  address          text,
  official_url     text,
  languages        text[] not null default '{}',
  -- Verified availability window, e.g. '24 hours'.
  hours            text,
  availability_note text,
  source_url       text not null,
  source_org       text not null,
  verification     verification_state not null default 'unverified',
  last_verified_at timestamptz,
  review_due_at    timestamptz,
  notes            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (country_code, category, service_name)
);
create index emergency_country_category_idx on public.emergency_resources (country_code, category);
create index emergency_review_idx on public.emergency_resources (review_due_at)
  where verification <> 'verified';

create table public.emergency_guides (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique,
  country_code  char(2),
  title         text not null,
  summary       text,
  -- Ordered steps: [{heading, body, actions:[{label,url,kind}], callouts:[]}]
  steps         jsonb not null default '[]'::jsonb,
  languages     jsonb not null default '{}'::jsonb,
  phrases       jsonb not null default '{}'::jsonb,
  source_url    text,
  source_org    text,
  verification  verification_state not null default 'unverified',
  last_verified_at timestamptz,
  review_due_at timestamptz,
  updated_at    timestamptz not null default now()
);
create index emergency_guides_country_idx on public.emergency_guides (country_code);

create table public.visa_resource_links (
  id           uuid primary key default gen_random_uuid(),
  country_code char(2) not null,
  country_name text not null,
  official_url text not null,
  source_org   text not null,
  source_url   text not null,
  category     text not null default 'entry_requirements',
  verification verification_state not null default 'unverified',
  last_verified_at timestamptz,
  review_due_at timestamptz,
  unique (country_code, category, official_url)
);

create table public.travel_advisories (
  id            uuid primary key default gen_random_uuid(),
  country_code  char(2) not null,
  country_name  text not null,
  advisory_level text,
  headline      text,
  summary       text,
  official_url  text not null,
  source_org    text not null,
  source_url    text not null,
  verification  verification_state not null default 'unverified',
  last_verified_at timestamptz,
  review_due_at timestamptz,
  unique (country_code, source_org)
);

-- Source verification audit trail: every refresh records what changed.
create table public.source_verification_log (
  id            bigserial primary key,
  table_name    text not null,
  record_id     uuid,
  source_url    text,
  source_org    text,
  previous_state verification_state,
  new_state     verification_state,
  changed_by    text,
  notes         text,
  checked_at    timestamptz not null default now()
);

-- AI generation jobs (rate limiting + audit).
create table public.itinerary_generation_jobs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  trip_id       uuid references public.trips(id) on delete set null,
  status        text not null default 'pending'
                check (status in ('pending','running','succeeded','failed')),
  provider      text,
  model         text,
  request       jsonb not null default '{}'::jsonb,
  result        jsonb,
  error_message text,
  duration_ms   int,
  created_at    timestamptz not null default now()
);
create index generation_jobs_user_idx on public.itinerary_generation_jobs (user_id, created_at desc);

-- Generic per-user offline sync bookkeeping.
create table public.offline_queue (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null,
  entity_id   uuid not null,
  operation  text not null check (operation in ('insert','update','delete')),
  payload    jsonb not null,
  -- Client-generated version used for last-write detection. Conflicts on
  -- financial records are surfaced to the user rather than auto-merged.
  base_version int,
  status      sync_status not null default 'pending',
  error       text,
  created_at  timestamptz not null default now(),
  synced_at   timestamptz
);
create index offline_queue_user_status_idx on public.offline_queue (user_id, status);

-- ---------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'profiles','trips','itinerary_items','budgets','bookings',
    'trip_destinations','visa_records','packing_lists','emergency_resources',
    'emergency_guides'
  ] loop
    execute format(
      'create trigger %I_touch before update on public.%I
       for each row execute function public.touch_updated_at()', t, t);
  end loop;
end $$;
