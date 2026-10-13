-- =====================================================================
-- TripSplit World — 0009 default currency
--
-- Changes the column defaults from USD to INR so a new profile, trip,
-- booking or expense starts in INR unless the user picks otherwise.
--
-- This is a new migration rather than an edit to 0001 on purpose: 0001 has
-- already been applied to at least one database, and editing an applied
-- migration makes the schema drift silently. `alter table ... alter column
-- ... set default` is idempotent, so re-running it is harmless.
--
-- Existing rows are deliberately untouched. Money already recorded stays in
-- whatever currency it was entered in; only the default for NEW records moves.
-- Rewriting historical rows would falsify the audit trail.
-- =====================================================================

alter table public.profiles
  alter column preferred_currency set default 'INR';

alter table public.trips
  alter column base_currency set default 'INR';

alter table public.itinerary_items
  alter column cost_currency set default 'INR';

alter table public.budgets
  alter column currency set default 'INR';

alter table public.bookings
  alter column currency set default 'INR';

alter table public.settlements
  alter column currency set default 'INR';

alter table public.destinations
  alter column currency set default 'INR';

alter table public.saved_destinations
  alter column currency set default 'INR';

-- New sign-ups should land on INR too. An explicit preference in the signup
-- metadata still wins.
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
    coalesce(new.raw_user_meta_data ->> 'preferred_currency', 'INR'),
    coalesce(new.raw_user_meta_data ->> 'preferred_language', 'en')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Confirm what landed, so a migration that silently did nothing is visible.
do $$
declare
  v_wrong text;
begin
  select string_agg(format('%s.%s=%s', table_name, column_name, column_default), ', ')
    into v_wrong
  from information_schema.columns
  where table_schema = 'public'
    and column_default in ('''USD''', '''USD''::bpchar', '''USD''::character')
    and column_name in ('preferred_currency', 'base_currency', 'cost_currency', 'currency');

  if v_wrong is not null then
    raise exception 'These currency columns still default to USD: %', v_wrong;
  end if;
end $$;