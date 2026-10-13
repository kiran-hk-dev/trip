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
    (v_trip, v_day, 'Dragon's Ridge sunset hike', 'experience',
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