-- =====================================================================
-- TripSplit World - 0010 Human-readable activity log
--
-- Problem: the expense_added activity summary was built with
--   format('%s added %s (%s)', p_paid_by::text, ...)
-- which renders the payer's raw UUID instead of a name, so "Recent
-- activity" read "3f1c...-9ab added Dinner (INR)".
--
-- This migration adds a display_name() resolver, uses it for future rows,
-- and repairs the rows already written.
--
-- Safety: display_name is SECURITY DEFINER STABLE with a fixed
-- search_path, and exposes only a display label - never an email
-- address or any other private field - so activity rows stay safe to
-- show to every member of a trip.
-- =====================================================================

-- Resolves a user id to something safe to show in a shared activity feed.
--
-- Deliberately does NOT return the email address: activity rows are
-- visible to every member of a trip, and an address is more identifying
-- than a name. Falls back to the local part of the email only when the
-- profile has no name at all.
create or replace function public.display_name(p_user uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_full_name text;
  v_email     text;
begin
  if p_user is null then
    return 'Someone';
  end if;

  select nullif(btrim(p.full_name), '') into v_full_name
  from public.profiles p where p.id = p_user;

  if v_full_name is not null then
    return v_full_name;
  end if;

  -- Fall back to the local part of the address only when there is no
  -- name at all. Never return the full address: activity rows are visible
  -- to every member of the trip.
  select u.email into v_email from auth.users u where u.id = p_user;

  return coalesce(nullif(split_part(coalesce(v_email, ''), '@', 1), ''), 'Someone');
end;
$$;

revoke all on function public.display_name(uuid) from public;
grant execute on function public.display_name(uuid) to authenticated;

-- --- create_expense with a readable actor ---------------------------
create or replace function public.create_expense(
  p_trip_id        uuid,
  p_title          text,
  p_amount_minor   bigint,
  p_currency       char(3),
  p_category       public.expense_category,
  p_expense_date   date,
  p_paid_by        uuid,
  p_split_method   public.split_method,
  p_participants   uuid[],
  p_shares         jsonb default null,   -- {user_id: minor_units}
  p_percentages    jsonb default null,   -- {user_id: percent}
  p_weights        jsonb default null,   -- {user_id: weight}
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
  v_key        text;
  v_amount     bigint;
  v_base       bigint;
  v_rate       numeric;
  v_uid        uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if not public.can_edit_trip(p_trip_id) then
    raise exception 'You do not have permission to add expenses to this trip'
      using errcode = '42501';
  end if;

  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip not found' using errcode = 'P0002';
  end if;

  -- Personal expenses have exactly one participant: the payer.
  if p_is_personal then
    v_ids := array[p_paid_by];
  else
    select coalesce(array_agg(distinct x), '{}'::uuid[])
      into v_ids
      from unnest(p_participants) x
      where x is not null;
  end if;

  if coalesce(array_length(v_ids, 1), 0) = 0 then
    raise exception 'Select at least one participant' using errcode = '22023';
  end if;

  -- Everyone involved must actually be an active member of this trip.
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
    raise exception 'The payer must be a member of this trip'
      using errcode = '42501';
  end if;

  v_total := p_amount_minor;
  if v_total <= 0 then
    raise exception 'Amount must be greater than zero' using errcode = '22023';
  end if;

  -- Compute shares.
  if p_is_personal or p_split_method = 'none' then
    v_shares := array[v_total];
  elsif p_split_method = 'equal' then
    v_shares := public.allocate_minor(v_total, array_fill(1::bigint, array[array_length(v_ids,1)]));
  elsif p_split_method = 'exact' then
    select array_agg(coalesce((p_shares ->> u::text)::bigint, 0)
                    order by ord)
      into v_shares
      from unnest(v_ids) with ordinality as t(u, ord);
    -- Repair any rounding discrepancy the user introduced rather than
    -- silently rejecting, so a 1-cent slip never loses money.
    v_sum_check := coalesce((select sum(x) from unnest(v_shares) x), 0);
    if v_sum_check <> v_total then
      v_shares := public.allocate_minor(v_total - v_sum_check, array_fill(1::bigint, array[array_length(v_ids,1)]));
      v_shares := array(
        select (coalesce((p_shares ->> u::text)::bigint, 0)
                + coalesce(v_shares[ord], 0))
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
      array_agg(round(((p_percentages ->> u::text)::numeric * 100))::bigint
                order by ord)
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

  -- Currency conversion. The original amount is always preserved; only a
  -- base-currency mirror is stored, using the supplied rate snapshot.
  if p_base_amount_minor is not null and p_base_amount_minor > 0 then
    v_base := p_base_amount_minor;
    v_rate := coalesce(p_fx_rate, 1);
  elsif p_currency = v_trip.base_currency then
    v_base := v_total;
    v_rate := 1;
  else
    raise exception
      'A base-currency amount and exchange rate are required for an expense in a different currency'
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
  select
    v_expense.id,
    p_trip_id,
    uid,
    share,
    -- Convert each share from the expense currency into the base currency,
    -- re-normalising so the base shares also sum exactly to the total.
    (share::numeric / v_total * v_base)::bigint,
    case when p_split_method = 'percentage' then ((p_percentages ->> uid::text)::numeric) end,
    case when p_split_method = 'shares' then ((p_weights ->> uid::text)::int) end
  from unnest(v_ids) with ordinality as t(uid, ord)
  join lateral (select v_shares[ord] as share) s on true;

  -- Fix the final base share so rounding cannot leave a stray minor unit.
  perform public.normalise_expense_base_shares(v_expense.id, v_base);

  perform public.log_activity(
    p_trip_id, 'expense', v_expense.id, 'expense_added',
    format('%s added %s (%s)', public.display_name(p_paid_by), p_title, p_currency),
    jsonb_build_object('amount_minor', v_total, 'currency', p_currency)
  );

  perform public.notify_trip_members(
    p_trip_id, 'expense_added', 'New expense added',
    format('%s was added to a trip you are part of.', p_title),
    jsonb_build_object('expense_id', v_expense.id)
  );

  return v_expense;
end;
$$;

-- Repair summaries already written with a UUID.
--
-- Only rows whose summary actually begins with the payer's UUID are
-- touched, so hand-written or already-correct summaries are left alone.
update public.activity_logs a
set summary = format(
  '%s added %s (%s)',
  public.display_name(a.user_id),
  -- Strip the leading "<uuid> " prefix.
  substr(a.summary, length(a.user_id::text) + 2),
  coalesce(a.metadata ->> 'currency', '')
)
where a.action = 'expense_added'
  and a.summary like a.user_id::text || ' %'
  and a.metadata ? 'currency';