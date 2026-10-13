-- =====================================================================
-- TripSplit World — 0006 demo seed
--
-- ALL DATA BELOW IS FICTIONAL. Every user, trip, expense and settlement here
-- is invented for demonstration and is clearly flagged with demo_account.
--
-- How to run:  supabase db reset            (applies migrations + this file)
-- How to wipe: supabase db reset --no-seed  then re-apply this file manually
--               supabase db reset
--
-- Demo profiles are marked demo_account = true and are excluded from
-- production analytics by that flag.
-- =====================================================================

-- Demo users are created through the auth schema. In a real Supabase project
-- you would create them via the Auth admin API or the dashboard; this block
-- documents the required shape so the fixture is reproducible:
--
--   demo.alice@tripsplit.example   password: DemoTrip!2026
--   demo.bob@tripsplit.example     password: DemoTrip!2026
--   demo.charlie@tripsplit.example password: DemoTrip!2026
--   demo.dana@tripsplit.example    password: DemoTrip!2026
--
-- Because auth.users cannot be safely inserted with a known password hash
-- from plain SQL, the trip fixtures below key off the profiles that the
-- auth trigger creates. `seed_demo_trip()` finds them by email and skips any
-- that are missing, so the migration is safe to run before the accounts
-- exist.

create or replace function public.seed_demo_trip()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alice uuid;
  v_bob   uuid;
  v_charlie uuid;
  v_dana  uuid;
  v_trip  uuid;
  v_budget uuid;
  v_hk    uuid;
  v_day   uuid;
  v_exp   uuid;
  v_cur   char(3);
begin
  select id into v_alice from auth.users where email = 'demo.alice@tripsplit.example';
  select id into v_bob   from auth.users where email = 'demo.bob@tripsplit.example';
  select id into v_charlie from auth.users where email = 'demo.charlie@tripsplit.example';
  select id into v_dana  from auth.users where email = 'demo.dana@tripsplit.example';

  if v_alice is null then
    raise notice 'Demo auth users not present yet — skipping demo trip fixture.';
    return null;
  end if;

  update public.profiles
  set full_name = case id
        when v_alice   then 'Alice Nakamura'
        when v_bob     then 'Bob Okafor'
        when v_charlie then 'Charlie Lindqvist'
        when v_dana    then 'Dana Rivera'
      end,
      demo_account = true,
      onboarding_completed = true,
      home_country = 'GB',
      preferred_currency = 'HKD'
  where id in (v_alice, v_bob, v_charlie, v_dana);

  -- ---------------- Trip 1: Hong Kong, multi-currency, live balances ----
  insert into public.trips (
    owner_id, name, description, origin, country_code,
    start_date, end_date, timezone, traveler_count,
    base_currency, total_budget_minor, contingency_pct,
    travel_style, travel_purpose, interests, cover_image_url, status
  )
  values (
    v_alice,
    'Hong Kong & Shenzhen Long Weekend',
    'Four friends, three days, two cities. Everything is logged in the currency it was actually paid in.',
    'London', 'HK',
    (current_date + 21), (current_date + 24), 'Asia/Hong_Kong', 4,
    'HKD', 3200000, 10,
    'balanced', 'city break',
    array['food','sightseeing','shopping','photography'],
    'https://images.unsplash.com/photo-1536599018102-9f803c140fc1?auto=format&fit=crop&w=1200&q=70',
    'upcoming'
  )
  returning id into v_trip;

  insert into public.trip_destinations (trip_id, position, name, country, country_code, city, latitude, longitude, timezone, arrival_date, departure_date)
  values
    (v_trip, 0, 'Hong Kong', 'Hong Kong SAR', 'HK', 'Hong Kong', 22.3193, 114.1694, 'Asia/Hong_Kong',
      (current_date + 21), (current_date + 23)),
    (v_trip, 1, 'Shenzhen', 'China', 'CN', 'Shenzhen', 22.5431, 114.0579, 'Asia/Shanghai',
      (current_date + 23), (current_date + 24));

  -- Members: the trigger already made Alice owner.
  insert into public.trip_members (trip_id, user_id, role)
  values (v_trip, v_bob, 'editor'),
         (v_trip, v_charlie, 'editor'),
         (v_trip, v_dana, 'viewer')
  on conflict do nothing;

  select id, base_currency into v_budget, v_cur
  from public.budgets where trip_id = v_trip;

  update public.budgets
  set total_minor = 3200000, contingency_minor = 320000, daily_limit_minor = 1330000
  where id = v_budget;

  insert into public.budget_categories (budget_id, trip_id, category, planned_minor, is_essential)
  values
    (v_budget, v_trip, 'flights',           900000, true),
    (v_budget, v_trip, 'accommodation',     800000, true),
    (v_budget, v_trip, 'food',              500000, false),
    (v_budget, v_trip, 'local_transport',   250000, false),
    (v_budget, v_trip, 'activities',        350000, false),
    (v_budget, v_trip, 'shopping',          200000, false),
    (v_budget, v_trip, 'insurance',          80000, true),
    (v_budget, v_trip, 'visa_fees',          40000, true),
    (v_budget, v_trip, 'connectivity',       40000, false),
    (v_budget, v_trip, 'medical',            80000, true);

  -- Itinerary: the trip trigger generated one day per trip date.
  select id into v_day from public.itinerary_days where trip_id = v_trip and day_number = 1;

  insert into public.itinerary_items
    (trip_id, day_id, title, kind, description, start_time, end_time,
     address, latitude, longitude, cost_minor, cost_currency, position, created_by)
  values
    (v_trip, v_day, 'Breakfast at Australia Dairy Company', 'restaurant',
     'Classic dai pai dong. Get there before 9am or expect a queue.',
     '08:30', '09:30', '47 Parkes Street, Central', 22.2949, 114.1700, 60000, 'HKD', 0, v_alice),
    (v_trip, v_day, 'Hong Kong Museum of Art', 'attraction',
     'Harbourfront campus. Free entry; closed on Thursdays.',
     '10:30', '12:30', '10 Salisbury Road, Central', 22.2936, 114.1707, 0, 'HKD', 1, v_alice),
    (v_trip, v_day, 'Star Ferry across the harbour', 'transport',
     'TST to Central. A few minutes, and the best cheap thing to do in the city.',
     '13:00', '13:30', 'Star Ferry Pier, Tsim Sha Tsui', 22.2933, 114.1740, 1000, 'HKD', 2, v_alice),
    (v_trip, v_day, 'Dim sum lunch in Sham Shui Po', 'restaurant',
     'Old teahouses. Go upstairs, it is quieter and cheaper.',
     '14:00', '16:00', 'Kite Street, Sham Shui Po', 22.3303, 114.1622, 90000, 'HKD', 3, v_bob),
    (v_trip, v_day, 'Dragon''s Ridge sunset hike', 'experience',
     'Moderate difficulty, about 6 km. Bring water and shoes with grip.',
     '16:30', '19:30', 'Tai Tam Reservoir', 22.4070, 114.1480, 0, 'HKD', 4, v_bob);

  -- ---------------- Expenses: mixed currencies, mixed split methods -------
  -- All of these go through create_expense() so shares are computed by the
  -- database exactly the way a real user's expenses would be.

  -- Equal split, paid in HKD by Alice, all four participate.
  perform public.create_expense_as(
    v_trip, 'Airport to Central, Octopus cards', 42000, 'HKD', 'HKD', 42000,
    'local_transport', v_alice, 'equal',
    array[v_alice, v_bob, v_charlie, v_dana], null, null, null, false,
    'Four Airport Express tickets. Card top-up done.'
  );

  -- Equal split in CNY (Shenzhen day) — converted to HKD base with a rate
  -- snapshot so the original amount is preserved.
  perform public.create_expense_as(
    v_trip, 'Shenzhen dinner — hotpot', 88000, 'CNY', 'HKD', 96000,
    'food', v_bob, 'equal',
    array[v_alice, v_bob, v_charlie, v_dana], null, null, null, false,
    'Paid in yuan. Converted at the rate shown, snapshot stored.'
  );

  -- Alice pays a larger share of the Airbnb: percentage split, 2 adults at
  -- 30% each, 2 friends at 20% each.
  perform public.create_expense_as(
    v_trip, 'Airbnb — 3 nights, Tsim Sha Tsui', 768000, 'HKD', 'HKD', 768000,
    'accommodation', v_alice, 'percentage',
    array[v_alice, v_bob, v_charlie, v_dana], null,
    jsonb_build_object(
      v_alice::text, 30.0, v_bob::text, 30.0,
      v_charlie::text, 20.0, v_dana::text, 20.0),
    null, false,
    'Booked on Alice''s card for the whole group.'
  );

  -- Charlie pays, weighted split (kids/regulars style weighting).
  perform public.create_expense_as(
    v_trip, 'Museum tickets', 96000, 'HKD', 'HKD', 96000,
    'activities', v_charlie, 'shares',
    array[v_alice, v_bob, v_charlie, v_dana], null, null,
    jsonb_build_object(v_alice::text, 1, v_bob::text, 1, v_charlie::text, 1, v_dana::text, 1),
    false, 'Four adult tickets.'
  );

  -- Dana pays for a group dinner — exact amounts, deliberately 1 cent short
  -- so the demo shows the rounding-repair warning path.
  perform public.create_expense_as(
    v_trip, 'Birthday dinner at K Lok', 456000, 'HKD', 'HKD', 456000,
    'food', v_dana, 'exact',
    array[v_alice, v_bob, v_charlie, v_dana],
    jsonb_build_object(
      v_alice::text, 152000, v_bob::text, 152000,
      v_charlie::text, 101000, v_dana::text, 50999),
    null, null, false,
    'Birthday meal. Custom amounts per person.'
  );

  -- Bob pays for a taxi with only three participants — Dana was not in the car.
  perform public.create_expense_as(
    v_trip, 'Taxi to the Peak', 36000, 'HKD', 'HKD', 36000,
    'local_transport', v_bob, 'equal',
    array[v_alice, v_bob, v_charlie], null, null, null, false,
    'Three passengers only.'
  );

  -- One personal expense, excluded from group balances entirely.
  perform public.create_expense_as(
    v_trip, 'Charlie — SIM card', 38000, 'HKD', 'HKD', 38000,
    'connectivity', v_charlie, 'none',
    array[v_charlie], null, null, null, true,
    'Personal expense, not shared.'
  );

  -- ---------------- One recorded settlement ----------------------------
  -- Recorded, NOT verified: this is a note that someone said they paid.
  perform public.record_settlement_as(
    v_trip, v_dana, v_alice, 100000, 'HKD', 'bank_transfer',
    'DEMO-REF-0001', 'Dana paid Alice back HKD 1,000 on the first night.',
    current_date - 1, v_alice
  );

  -- ---------------- Second trip: personal, not yet started ---------------
  insert into public.trips (
    owner_id, name, description, origin, country_code,
    start_date, end_date, timezone, traveler_count, base_currency,
    total_budget_minor, travel_style, interests, status
  )
  values (
    v_alice, 'Lisbon in spring', 'A solo long weekend. Budget tracked in euros.',
    'London', 'PT',
    (current_date + 95), (current_date + 99), 'Europe/Lisbon', 1, 'EUR',
    90000, 'budget', array['food','heritage','city'],
    'planning'
  );

  raise notice 'Demo trip seeded: %', v_trip;
  return v_trip;
end;
$$;

-- Friend wrappers that bypass the auth.uid() checks so the seed can build a
-- realistic multi-user fixture in one migration. They are SECURITY DEFINER
-- and are revoked from public/exec in the accompanying grant migration.
--
-- These call the *_internal functions directly with an explicit acting user.
-- They deliberately do NOT go through the client-facing create_expense() /
-- record_settlement() wrappers: an earlier version of this file redefined those
-- to fall back to a session GUC (`app.seed_actor`) when auth.uid() was null.
-- Any authenticated client can set a custom GUC, so that fallback let a caller
-- impersonate any user by choosing the GUC value. Wrapping the internal
-- functions keeps the impersonation path inside functions that are revoked
-- from anon and authenticated.
create or replace function public.create_expense_as(
  p_trip_id uuid, p_title text, p_amount_minor bigint,
  p_currency char(3), p_base_currency char(3), p_base_amount_minor bigint,
  p_category public.expense_category, p_paid_by uuid,
  p_split_method public.split_method, p_participants uuid[],
  p_shares jsonb, p_percentages jsonb, p_weights jsonb,
  p_is_personal boolean, p_notes text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Act as the payer so every permission check inside the internal function
  -- passes. Returns a row we discard, hence PERFORM rather than RETURN.
  perform public.create_expense_internal(
    p_paid_by,
    p_trip_id, p_title, p_amount_minor, p_currency, p_category,
    current_date, p_paid_by, p_split_method, p_participants,
    p_shares, p_percentages, p_weights, p_is_personal, p_notes,
    null, p_base_amount_minor,
    case when p_currency = p_base_currency then 1
         else round(p_base_amount_minor::numeric / p_amount_minor, 10) end,
    case when p_currency = p_base_currency then null else 'demo-fixture' end
  );
end;
$$;

create or replace function public.record_settlement_as(
  p_trip_id uuid, p_from uuid, p_to uuid, p_amount bigint, p_currency char(3),
  p_method public.settlement_method, p_reference text, p_notes text,
  p_settled_at date, p_actor uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_result public.settlements;
begin
  v_result := public.record_settlement_internal(
    p_actor, p_trip_id, p_from, p_to, p_amount, p_currency, p_method,
    p_reference, p_notes, p_settled_at, p_amount, 1, null,
    'demo-' || gen_random_uuid()::text
  );
end;
$$;

create or replace function public.create_expense_internal(
  v_uid uuid,
  p_trip_id        uuid,
  p_title          text,
  p_amount_minor   bigint,
  p_currency       char(3),
  p_category       public.expense_category,
  p_expense_date   date,
  p_paid_by        uuid,
  p_split_method   public.split_method,
  p_participants   uuid[],
  p_shares         jsonb default null,
  p_percentages    jsonb default null,
  p_weights        jsonb default null,
  p_is_personal    boolean default false,
  p_notes          text default null,
  p_receipt_path   text default null,
  p_base_amount_minor bigint default null,
  p_fx_rate        numeric default null,
  p_fx_provider    text default null
)
returns public.expenses
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expense    public.expenses;
  v_trip       public.trips;
  v_ids        uuid[];
  v_shares     bigint[];
  v_total      bigint;
  v_sum_check  bigint;
  v_repair     bigint[];
  v_base       bigint;
  v_rate       numeric;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  -- Permission check evaluated as the acting user.
  if not exists (
    select 1 from public.trip_members m
    where m.trip_id = p_trip_id and m.user_id = v_uid
      and m.status = 'active' and m.role in ('owner','admin','editor')
  ) then
    raise exception 'You do not have permission to add expenses to this trip'
      using errcode = '42501';
  end if;

  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip not found' using errcode = 'P0002';
  end if;

  if p_is_personal then
    v_ids := array[p_paid_by];
  else
    select coalesce(array_agg(distinct x), '{}'::uuid[]) into v_ids
    from unnest(p_participants) x where x is not null;
  end if;

  if coalesce(array_length(v_ids, 1), 0) = 0 then
    raise exception 'Select at least one participant' using errcode = '22023';
  end if;

  if exists (
    select 1 from unnest(v_ids) x
    where not exists (
      select 1 from public.trip_members m
      where m.trip_id = p_trip_id and m.user_id = x and m.status = 'active'
    )
  ) then
    raise exception 'One or more participants are not members of this trip'
      using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.trip_members m
    where m.trip_id = p_trip_id and m.user_id = p_paid_by and m.status = 'active'
  ) then
    raise exception 'The payer must be a member of this trip' using errcode = '42501';
  end if;

  v_total := p_amount_minor;
  if v_total <= 0 then
    raise exception 'Amount must be greater than zero' using errcode = '22023';
  end if;

  if p_is_personal or p_split_method = 'none' then
    v_shares := array[v_total];
  elsif p_split_method = 'equal' then
    v_shares := public.allocate_minor(v_total, array_fill(1::bigint, array[array_length(v_ids,1)]));
  elsif p_split_method = 'exact' then
    select array_agg(coalesce((p_shares ->> u::text)::bigint, 0) order by ord)
      into v_shares
    from unnest(v_ids) with ordinality as t(u, ord);

    v_sum_check := coalesce((select sum(x) from unnest(v_shares) x), 0);
    if v_sum_check <> v_total then
      -- Hoist the repair allocation into a variable: Postgres cannot subscript
      -- a bare function call inside a plpgsql expression.
      select public.allocate_minor(
               v_total - v_sum_check,
               array_fill(1::bigint, array[array_length(v_ids,1)]))
        into v_repair;

      v_shares := array(
        select coalesce((p_shares ->> u::text)::bigint, 0) + v_repair[ord]
        from unnest(v_ids) with ordinality as t(u, ord)
      );
    end if;
  elsif p_split_method = 'percentage' then
    if abs(coalesce((select sum((p_percentages ->> u::text)::numeric)
                       from unnest(v_ids) u), 0) - 100) > 0.01 then
      raise exception 'Percentages must add up to 100' using errcode = '22023';
    end if;
    v_shares := public.allocate_minor(
      v_total,
      array_agg(round(((p_percentages ->> u::text)::numeric * 100))::bigint order by ord)
    ) from (select u, ord from unnest(v_ids) with ordinality as tt(u, ord)) q;
  elsif p_split_method = 'shares' then
    v_shares := public.allocate_minor(
      v_total,
      array_agg(coalesce((p_weights ->> u::text)::bigint, 0) order by ord)
    ) from (select u, ord from unnest(v_ids) with ordinality as tt(u, ord)) q;
    if coalesce((select sum(x) from unnest(v_shares) x), 0) = 0 then
      raise exception 'At least one participant needs a share above zero'
        using errcode = '22023';
    end if;
  else
    raise exception 'Unsupported split method' using errcode = '22023';
  end if;

  if coalesce((select sum(x) from unnest(v_shares) x), 0) <> v_total then
    raise exception 'Internal allocation error: shares do not sum to the total'
      using errcode = '40001';
  end if;

  if p_base_amount_minor is not null and p_base_amount_minor > 0 then
    v_base := p_base_amount_minor;
    v_rate := coalesce(p_fx_rate, 1);
  elsif p_currency = v_trip.base_currency then
    v_base := v_total;
    v_rate := 1;
  else
    raise exception
      'A base-currency amount and exchange rate are required for a different currency'
      using errcode = '22023';
  end if;

  insert into public.expenses (
    trip_id, title, amount_minor, currency, base_amount_minor,
    fx_rate, fx_provider, fx_fetched_at, category, expense_date, paid_by,
    split_method, is_personal, notes, receipt_path, participant_ids, created_by
  )
  values (
    p_trip_id, btrim(p_title), v_total, upper(p_currency), v_base,
    v_rate, p_fx_provider, case when p_fx_provider is null then null else now() end,
    p_category, coalesce(p_expense_date, current_date), p_paid_by,
    p_split_method, coalesce(p_is_personal, false), p_notes, p_receipt_path,
    v_ids, v_uid
  )
  returning * into v_expense;

  insert into public.expense_participants (expense_id, trip_id, user_id)
  select v_expense.id, p_trip_id, x from unnest(v_ids) x;

  insert into public.expense_shares (expense_id, trip_id, user_id, amount_minor, base_amount_minor, percentage, weight)
  select v_expense.id, p_trip_id, uid, share,
         (share::numeric / v_total * v_base)::bigint,
         case when p_split_method = 'percentage' then ((p_percentages ->> uid::text)::numeric) end,
         case when p_split_method = 'shares' then ((p_weights ->> uid::text)::int) end
  from unnest(v_ids) with ordinality as t(uid, ord)
  join lateral (select v_shares[ord] as share) s on true;

  perform public.normalise_expense_base_shares(v_expense.id, v_base);

  insert into public.activity_logs (trip_id, user_id, entity_type, entity_id, action, summary)
  values (p_trip_id, v_uid, 'expense', v_expense.id, 'expense_added',
          format('%s added %s (%s)', p_paid_by::text, p_title, p_currency));

  return v_expense;
end;
$$;

-- record_settlement() is defined in 0003 and resolves its acting user from
-- auth.uid(). It is deliberately NOT redefined here: doing so previously
-- introduced an impersonation path. The *_as wrapper above calls
-- record_settlement_internal() directly instead.

create or replace function public.record_settlement_internal(
  v_uid           uuid,
  p_trip_id        uuid,
  p_from_user_id   uuid,
  p_to_user_id     uuid,
  p_amount_minor   bigint,
  p_currency       char(3),
  p_method         public.settlement_method,
  p_reference      text,
  p_notes          text,
  p_settled_at     date,
  p_base_amount_minor bigint,
  p_fx_rate        numeric,
  p_fx_provider    text,
  p_idempotency_key text
)
returns public.settlements
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip       public.trips;
  v_settlement public.settlements;
  v_max        bigint;
  v_recipient_net bigint;
  v_base       bigint;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if not exists (
    select 1 from public.trip_members m
    where m.trip_id = p_trip_id and m.user_id = v_uid
      and m.status = 'active' and m.role in ('owner','admin','editor')
  ) then
    raise exception 'You do not have permission to record settlements for this trip'
      using errcode = '42501';
  end if;

  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip not found' using errcode = 'P0002';
  end if;

  -- Idempotency: a retried request must never double-record a payment.
  if p_idempotency_key is not null then
    select * into v_settlement from public.settlements where idempotency_key = p_idempotency_key;
    if found then return v_settlement; end if;
  end if;

  if p_from_user_id = p_to_user_id then
    raise exception 'A member cannot settle with themselves' using errcode = '22023';
  end if;
  if p_amount_minor <= 0 then
    raise exception 'Amount must be greater than zero' using errcode = '22023';
  end if;

  if not exists (select 1 from public.trip_members m
                 where m.trip_id = p_trip_id and m.user_id = p_from_user_id and m.status = 'active')
     or not exists (select 1 from public.trip_members m
                 where m.trip_id = p_trip_id and m.user_id = p_to_user_id and m.status = 'active') then
    raise exception 'Both members must belong to this trip' using errcode = '42501';
  end if;

  select -net_minor into v_max
  from public.trip_balances(p_trip_id) where user_id = p_from_user_id;

  if v_max is null or v_max <= 0 then
    raise exception 'This member does not owe anything in this trip' using errcode = '22023';
  end if;

  select net_minor into v_recipient_net
  from public.trip_balances(p_trip_id) where user_id = p_to_user_id;

  if v_recipient_net is null or v_recipient_net <= 0 then
    raise exception 'This member is not owed anything in this trip' using errcode = '22023';
  end if;

  v_max := least(v_max, v_recipient_net);
  if p_amount_minor > v_max then
    -- RAISE EXCEPTION takes a format string directly; wrapping it in
    -- format(...) makes the parser read 'format' as an exception condition.
    raise exception 'Maximum valid settlement is %s %s', v_max, v_trip.base_currency
      using errcode = '22023';
  end if;

  if p_base_amount_minor is not null and p_base_amount_minor > 0 then
    v_base := p_base_amount_minor;
  elsif p_currency = v_trip.base_currency then
    v_base := p_amount_minor;
  else
    raise exception
      'A base-currency amount and exchange rate are required to settle in a different currency'
      using errcode = '22023';
  end if;

  insert into public.settlements (
    trip_id, from_user_id, to_user_id, amount_minor, currency,
    base_amount_minor, fx_rate, fx_provider, fx_fetched_at,
    status, method, reference, notes, settled_at, idempotency_key, created_by
  )
  values (
    p_trip_id, p_from_user_id, p_to_user_id, p_amount_minor, upper(p_currency),
    v_base, coalesce(p_fx_rate, 1), p_fx_provider,
    case when p_fx_provider is null then null else now() end,
    -- 'recorded' only. Verification requires a provider webhook (service role).
    'recorded', p_method, p_reference, p_notes, coalesce(p_settled_at, current_date),
    p_idempotency_key, v_uid
  )
  returning * into v_settlement;

  insert into public.settlement_allocations (settlement_id, trip_id, user_id, base_amount_minor)
  values (v_settlement.id, p_trip_id, p_from_user_id, v_base),
         (v_settlement.id, p_trip_id, p_to_user_id, -v_base);

  insert into public.activity_logs (trip_id, user_id, entity_type, entity_id, action, summary)
  values (p_trip_id, v_uid, 'settlement', v_settlement.id, 'settlement_recorded',
          format('Settlement recorded: %s', p_amount_minor));

  insert into public.notifications (user_id, kind, title, body, trip_id, payload)
  values (p_to_user_id, 'settlement', 'Settlement recorded',
          format('A settlement of %s %s was recorded in your favour.', p_amount_minor, p_currency),
          p_trip_id, jsonb_build_object('settlement_id', v_settlement.id));

  return v_settlement;
end;
$$;

