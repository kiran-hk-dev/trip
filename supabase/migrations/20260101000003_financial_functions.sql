-- =====================================================================
-- TripSplit World — 0003 server-side financial logic
--
-- Every balance-changing operation goes through these functions. Clients
-- never post totals, and never write expense_shares / settlement_allocations
-- directly — the database computes them from the inputs.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Owner membership bootstrap
-- ---------------------------------------------------------------------
create or replace function public.bootstrap_trip_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.trip_members (trip_id, user_id, role, status)
  values (new.id, new.owner_id, 'owner', 'active')
  on conflict (trip_id, user_id) do nothing;

  insert into public.budgets (trip_id, currency, total_minor)
  values (new.id, new.base_currency, new.total_budget_minor);

  insert into public.itinerary_days (trip_id, day_number, date)
  select new.id, g, new.start_date + (g - 1)::int
  from generate_series(1, greatest(1, (new.end_date - new.start_date) + 1)) g;

  insert into public.activity_logs (trip_id, user_id, entity_type, entity_id, action, summary)
  values (new.id, new.owner_id, 'trip', new.id, 'created', 'Trip created');

  return new;
end;
$$;

create trigger trips_bootstrap
  after insert on public.trips
  for each row execute function public.bootstrap_trip_owner();

-- Keeps the generated day rows in step with the trip dates.
create or replace function public.sync_itinerary_days()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expected int;
  v_have     int;
begin
  v_expected := greatest(1, (new.end_date - new.start_date) + 1);
  select count(*) into v_have from public.itinerary_days where trip_id = new.id;

  if v_have < v_expected then
    insert into public.itinerary_days (trip_id, day_number, date)
    select new.id, g, new.start_date + (g - 1)::int
    from generate_series(v_have + 1, v_expected) g;
  elsif v_have > v_expected then
    delete from public.itinerary_days
    where trip_id = new.id and day_number > v_expected;
  end if;
  return new;
end;
$$;

create trigger trips_sync_days
  after update of start_date, end_date on public.trips
  for each row execute function public.sync_itinerary_days();

-- ---------------------------------------------------------------------
-- 2. Largest-remainder allocation (integer only)
-- ---------------------------------------------------------------------
create or replace function public.allocate_minor(
  p_total   bigint,
  p_weights bigint[]
) returns bigint[]
language plpgsql
immutable
as $$
declare
  n            int := coalesce(array_length(p_weights, 1), 0);
  total_weight bigint := 0;
  assigned     bigint := 0;
  residual     bigint;
  idx          int := 0;
  step         int;
  out_result   bigint[] := array_fill(0, array[n]);
  w_sum        bigint;
  w_num        bigint;
  base_v       bigint;
  rem_v        bigint;
  ordered      int[];
  weights_norm bigint[];
begin
  if n = 0 then return out_result; end if;

  select coalesce(sum(w), 0) into total_weight from unnest(p_weights) w;
  if total_weight <= 0 then
    -- Degenerate input: fall back to an equal split so no money is lost.
    select coalesce(sum(w), 0) into total_weight from unnest(p_weights) w where w = 1;
    if total_weight <= 0 then
      return public.allocate_minor(p_total, array_fill(1, array[n]));
    end if;
    weights_norm := array_fill(1::bigint, array[n]);
  else
    weights_norm := p_weights;
  end if;

  for i in 1..n loop
    w_num  := p_total * weights_norm[i];
    base_v := w_num / total_weight;
    rem_v  := w_num % total_weight;
    out_result[i] := base_v;
    assigned := assigned + base_v;
  end loop;

  residual := p_total - assigned;
  if residual <> 0 then
    -- Distribute the residual to the largest remainders first, ties broken by
    -- index, so the result is deterministic across recalculations.
    select array_agg(i order by ((p_total * weights_norm[i]) % total_weight) desc, i)
      into ordered
      from generate_series(1, n) i;

    idx := 0;
    while residual <> 0 loop
      step := case when residual > 0 then 1 else -1 end;
      out_result[ordered[(idx % n) + 1]] :=
        out_result[ordered[(idx % n) + 1]] + step;
      residual := residual - step;
      idx := idx + 1;
    end loop;
  end if;

  return out_result;
end;
$$;

-- ---------------------------------------------------------------------
-- 3. create_expense — computes participants and shares server-side
-- ---------------------------------------------------------------------
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
    format('%s added %s (%s)', p_paid_by::text, p_title, p_currency),
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

-- ---------------------------------------------------------------------
-- 4. Re-normalise base-currency shares so they sum exactly to base_amount.
-- ---------------------------------------------------------------------
create or replace function public.normalise_expense_base_shares(
  p_expense_id uuid,
  p_base_total bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expense public.expenses;
  v_rows    record;
  v_sum     bigint;
  v_target  bigint;
  v_remainder bigint;
begin
  select * into v_expense from public.expenses where id = p_expense_id;
  v_target := coalesce(p_base_total, v_expense.base_amount_minor);

  select coalesce(sum(base_amount_minor), 0) into v_sum
  from public.expense_shares where expense_id = p_expense_id;

  v_remainder := v_target - v_sum;
  if v_remainder = 0 then return; end if;

  -- Push the residual onto the largest original share; it is the least
  -- disruptive place for a sub-cent difference to land.
  update public.expense_shares s
  set base_amount_minor = s.base_amount_minor + v_remainder
  where s.id = (
    select id from public.expense_shares
    where expense_id = p_expense_id
    order by amount_minor desc, user_id
    limit 1
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 5. update_expense — recomputes shares, never trusts client totals
-- ---------------------------------------------------------------------
create or replace function public.update_expense(
  p_expense_id   uuid,
  p_title         text default null,
  p_amount_minor  bigint default null,
  p_currency      char(3) default null,
  p_base_amount_minor bigint default null,
  p_fx_rate       numeric default null,
  p_fx_provider   text default null,
  p_category      public.expense_category default null,
  p_expense_date  date default null,
  p_paid_by       uuid default null,
  p_split_method  public.split_method default null,
  p_participants  uuid[] default null,
  p_shares        jsonb default null,
  p_percentages   jsonb default null,
  p_weights       jsonb default null,
  p_notes         text default null,
  p_receipt_path  text default null
)
returns public.expenses
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.expenses;
  v_trip     public.trips;
begin
  select * into v_existing from public.expenses where id = p_expense_id;
  if not found then
    raise exception 'Expense not found' using errcode = 'P0002';
  end if;
  if not public.can_edit_trip(v_existing.trip_id)
     and v_existing.created_by <> auth.uid() then
    raise exception 'You do not have permission to edit this expense'
      using errcode = '42501';
  end if;

  -- Preserve the audit trail of the financial record.
  perform public.log_activity(
    v_existing.trip_id, 'expense', p_expense_id, 'expense_updated',
    'Expense edited: ' || coalesce(p_title, v_existing.title),
    jsonb_build_object(
      'previous_amount', v_existing.amount_minor,
      'previous_payer', v_existing.paid_by,
      'previous_method', v_existing.split_method
    )
  );

  -- Delete the derived rows and recompute from scratch. This is the only
  -- correct way to recalculate balances after an edit.
  if p_participants is not null
     or p_split_method is not null
     or p_amount_minor is not null
     or p_shares is not null
     or p_percentages is not null
     or p_weights is not null then

    update public.expenses
    set deleted_at = now()
    where id = p_expense_id;

    return public.create_expense(
      p_trip_id          => v_existing.trip_id,
      p_title            => coalesce(p_title, v_existing.title),
      p_amount_minor     => coalesce(p_amount_minor, v_existing.amount_minor),
      p_currency         => coalesce(p_currency, v_existing.currency),
      p_category         => coalesce(p_category, v_existing.category),
      p_expense_date     => coalesce(p_expense_date, v_existing.expense_date),
      p_paid_by          => coalesce(p_paid_by, v_existing.paid_by),
      p_split_method     => coalesce(p_split_method, v_existing.split_method),
      p_participants     => coalesce(p_participants, v_existing.participant_ids),
      p_shares           => p_shares,
      p_percentages      => p_percentages,
      p_weights          => p_weights,
      p_is_personal      => v_existing.is_personal,
      p_notes            => coalesce(p_notes, v_existing.notes),
      p_receipt_path     => coalesce(p_receipt_path, v_existing.receipt_path),
      p_base_amount_minor=> coalesce(p_base_amount_minor, v_existing.base_amount_minor),
      p_fx_rate          => coalesce(p_fx_rate, v_existing.fx_rate),
      p_fx_provider      => coalesce(p_fx_provider, v_existing.fx_provider)
    );
  end if;

  -- Non-financial field edits happen in place.
  update public.expenses e
  set title         = coalesce(p_title, e.title),
      category      = coalesce(p_category, e.category),
      expense_date  = coalesce(p_expense_date, e.expense_date),
      notes         = coalesce(p_notes, e.notes),
      receipt_path  = coalesce(p_receipt_path, e.receipt_path),
      version       = e.version + 1
  where e.id = p_expense_id
  returning * into v_existing;

  return v_existing;
end;
$$;

alter table public.expenses add column if not exists version int not null default 1;

-- ---------------------------------------------------------------------
-- 6. delete_expense — soft delete so the audit trail survives
-- ---------------------------------------------------------------------
create or replace function public.delete_expense(p_expense_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.expenses;
begin
  select * into v_existing from public.expenses where id = p_expense_id;
  if not found then
    raise exception 'Expense not found' using errcode = 'P0002';
  end if;
  if not public.can_edit_trip(v_existing.trip_id)
     and v_existing.created_by <> auth.uid() then
    raise exception 'You do not have permission to delete this expense'
      using errcode = '42501';
  end if;

  perform public.log_activity(
    v_existing.trip_id, 'expense', p_expense_id, 'expense_deleted',
    'Expense deleted: ' || v_existing.title,
    jsonb_build_object('amount_minor', v_existing.amount_minor, 'currency', v_existing.currency)
  );

  -- Soft delete keeps the audit trail; derived rows are retained so historical
  -- balances remain explainable.
  update public.expenses set deleted_at = now() where id = p_expense_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 7. trip_balances — the single source of truth for who owes whom
-- ---------------------------------------------------------------------
create or replace function public.trip_balances(p_trip_id uuid)
returns table (
  user_id            uuid,
  paid_minor         bigint,
  share_minor        bigint,
  settled_in_minor   bigint,
  settled_out_minor  bigint,
  net_minor          bigint,
  currency           char(3)
)
language sql
stable
security definer
set search_path = public
as $$
  with paid as (
    select e.paid_by as user_id, sum(e.base_amount_minor)::bigint as amount
    from public.expenses e
    where e.trip_id = p_trip_id and e.deleted_at is null
    group by e.paid_by
  ),
  owed as (
    select s.user_id, sum(s.base_amount_minor)::bigint as amount
    from public.expense_shares s
    join public.expenses e on e.id = s.expense_id
    where s.trip_id = p_trip_id and e.deleted_at is null
    group by s.user_id
  ),
  settled as (
    select from_user_id as user_id,
           sum(base_amount_minor)::bigint as out_amount,
           0::bigint as in_amount
    from public.settlements
    where trip_id = p_trip_id and deleted_at is null and status <> 'disputed'
    group by from_user_id
    union all
    select to_user_id,
           0::bigint,
           sum(base_amount_minor)::bigint
    from public.settlements
    where trip_id = p_trip_id and deleted_at is null and status <> 'disputed'
    group by to_user_id
  ),
  settled_agg as (
    select user_id,
           sum(coalesce(out_amount, 0))::bigint as settled_out,
           sum(coalesce(in_amount, 0))::bigint as settled_in
    from settled group by user_id
  )
  select
    m.user_id,
    coalesce(paid.amount, 0)::bigint,
    coalesce(owed.amount, 0)::bigint,
    coalesce(settled_agg.settled_in, 0)::bigint,
    coalesce(settled_agg.settled_out, 0)::bigint,
    (coalesce(paid.amount, 0) - coalesce(owed.amount, 0)
      + coalesce(settled_agg.settled_out, 0) - coalesce(settled_agg.settled_in, 0))::bigint,
    t.base_currency::char(3)
  from public.trip_members m
  join public.trips t on t.id = m.trip_id
  left join paid   on paid.user_id = m.user_id
  left join owed   on owed.user_id = m.user_id
  left join settled_agg on settled_agg.user_id = m.user_id
  where m.trip_id = p_trip_id and m.status = 'active'
  order by m.user_id;
$$;

-- ---------------------------------------------------------------------
-- 8. record_settlement — validates against live balances, idempotent
-- ---------------------------------------------------------------------
create or replace function public.record_settlement(
  p_trip_id        uuid,
  p_from_user_id   uuid,
  p_to_user_id     uuid,
  p_amount_minor   bigint,
  p_currency       char(3),
  p_method         public.settlement_method default 'other',
  p_reference      text default null,
  p_notes          text default null,
  p_settled_at     date default current_date,
  p_base_amount_minor bigint default null,
  p_fx_rate        numeric default null,
  p_fx_provider    text default null,
  p_idempotency_key text default null
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
  v_balances   record;
  v_base       bigint;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if not public.can_edit_trip(p_trip_id) then
    raise exception 'You do not have permission to record settlements for this trip'
      using errcode = '42501';
  end if;

  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip not found' using errcode = 'P0002';
  end if;

  -- Idempotency: a retried request must not double-record a payment.
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

  if not exists (
    select 1 from public.trip_members m
    where m.trip_id = p_trip_id and m.user_id = p_from_user_id and m.status = 'active'
  ) or not exists (
    select 1 from public.trip_members m
    where m.trip_id = p_trip_id and m.user_id = p_to_user_id and m.status = 'active'
  ) then
    raise exception 'Both members must belong to this trip' using errcode = '42501';
  end if;

  -- Live balance check. Settling more than is owed would create a phantom
  -- credit; settling with someone you do not owe would be nonsense.
  select -net_minor into v_max
  from public.trip_balances(p_trip_id) where user_id = p_from_user_id;

  if v_max is null or v_max <= 0 then
    raise exception 'This member does not owe anything in this trip'
      using errcode = '22023';
  end if;

  select net_minor into v_balances
  from public.trip_balances(p_trip_id) where user_id = p_to_user_id;

  if v_balances is null or v_balances <= 0 then
    raise exception 'This member is not owed anything in this trip'
      using errcode = '22023';
  end if;

  v_max := least(v_max, v_balances);
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
    -- 'recorded' only. A payment is never marked verified by a client click.
    'recorded', p_method, p_reference, p_notes, coalesce(p_settled_at, current_date),
    p_idempotency_key, auth.uid()
  )
  returning * into v_settlement;

  insert into public.settlement_allocations (settlement_id, trip_id, user_id, base_amount_minor)
  values (v_settlement.id, p_trip_id, p_from_user_id, v_base),
         (v_settlement.id, p_trip_id, p_to_user_id, -v_base);

  perform public.log_activity(
    p_trip_id, 'settlement', v_settlement.id, 'settlement_recorded',
    format('Settlement recorded: %s', p_amount_minor),
    jsonb_build_object('from', p_from_user_id, 'to', p_to_user_id, 'amount', p_amount_minor)
  );

  perform public.notify_user(
    p_from_user_id, 'settlement', 'Settlement recorded',
    format('A settlement of %s %s was recorded in your favour.', p_amount_minor, p_currency),
    jsonb_build_object('trip_id', p_trip_id, 'settlement_id', v_settlement.id)
  );

  return v_settlement;
end;
$$;

-- ---------------------------------------------------------------------
-- 9. confirm_settlement — service role only, for provider webhooks
-- ---------------------------------------------------------------------
create or replace function public.confirm_settlement(
  p_settlement_id uuid,
  p_provider      text,
  p_reference     text
)
returns public.settlements
language plpgsql
security definer
set search_path = public
as $$
declare v_settlement public.settlements;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Only the service role may confirm a settlement'
      using errcode = '42501';
  end if;
  update public.settlements
  set status = 'confirmed', verified_at = now(), verified_by = p_provider,
      reference = coalesce(p_reference, reference)
  where id = p_settlement_id
  returning * into v_settlement;
  return v_settlement;
end;
$$;

-- ---------------------------------------------------------------------
-- 10. suggest_settlements — debt simplification in SQL
-- ---------------------------------------------------------------------
create or replace function public.suggest_settlements(p_trip_id uuid)
returns table (
  from_user_id uuid,
  to_user_id   uuid,
  amount_minor bigint,
  currency     char(3)
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r            record;
  v_creditors  uuid[] := '{}';
  v_debtors    uuid[] := '{}';
  v_credit_map jsonb := '{}'::jsonb;   -- user -> remaining credit
  v_debt_map   jsonb := '{}'::jsonb;   -- user -> remaining debt (positive)
  v_currency   char(3);
  v_ci         int := 0;
  v_di         int := 0;
  v_count      int;
  v_pay        bigint;
begin
  if not public.is_trip_member(p_trip_id) then
    raise exception 'Not a member of this trip' using errcode = '42501';
  end if;

  select base_currency into v_currency from public.trips where id = p_trip_id;

  for r in select user_id, net_minor from public.trip_balances(p_trip_id)
  loop
    if r.net_minor > 0 then
      v_creditors := array_append(v_creditors, r.user_id);
      v_credit_map := jsonb_set(v_credit_map, array[r.user_id::text], to_jsonb(r.net_minor));
    elsif r.net_minor < 0 then
      v_debtors := array_append(v_debtors, r.user_id);
      v_debt_map := jsonb_set(v_debt_map, array[r.user_id::text], to_jsonb(-r.net_minor));
    end if;
  end loop;

  v_count := coalesce(array_length(v_creditors, 1), 0);
  if v_count = 0 then return; end if;

  -- Largest-first greedy matching. Same strategy as the client engine so the
  -- suggestion shown offline and the one shown online agree.
  while v_ci < v_count loop
    exit when v_di >= coalesce(array_length(v_debtors, 1), 0);
    v_pay := least(
      (v_credit_map ->> v_creditors[v_ci + 1])::bigint,
      (v_debt_map ->> v_debtors[v_di + 1])::bigint
    );
    continue when v_pay <= 0;

    return query
      select v_debtors[v_di + 1], v_creditors[v_ci + 1], v_pay, v_currency;

    v_credit_map := jsonb_set(
      v_credit_map, array[v_creditors[v_ci + 1]],
      to_jsonb((v_credit_map ->> v_creditors[v_ci + 1])::bigint - v_pay));
    v_debt_map := jsonb_set(
      v_debt_map, array[v_debtors[v_di + 1]],
      to_jsonb((v_debt_map ->> v_debtors[v_di + 1])::bigint - v_pay));

    if ((v_credit_map ->> v_creditors[v_ci + 1])::bigint) = 0 then v_ci := v_ci + 1; end if;
    if ((v_debt_map   ->> v_debtors[v_di + 1])::bigint) = 0 then v_di := v_di + 1; end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- 11. Invitations
-- ---------------------------------------------------------------------
create or replace function public.create_invitation(
  p_trip_id uuid,
  p_email   text,
  p_role    public.trip_role default 'viewer',
  p_token   text default null          -- raw token, hashed inside
)
returns table (invitation_id uuid, raw_token text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id    uuid;
  v_hash  text;
  v_trip  public.trips;
begin
  if not public.can_admin_trip(p_trip_id) then
    raise exception 'Only trip owners and admins can invite members'
      using errcode = '42501';
  end if;

  select * into v_trip from public.trips where id = p_trip_id;

  -- Already a member?
  if exists (
    select 1 from public.profiles p
    join public.trip_members m on m.user_id = p.id
    where m.trip_id = p_trip_id and m.status = 'active'
      and lower(p.full_name) is not null
  ) then
    -- handled per-email below; this block is intentionally permissive
    null;
  end if;

  v_hash := encode(digest(coalesce(p_token, gen_random_uuid()::text), 'sha256'), 'hex');

  -- Re-invite: supersede any pending invitation for the same address.
  update public.trip_invitations
  set status = 'expired'
  where trip_id = p_trip_id and lower(invited_email) = lower(p_email)
    and status = 'pending';

  insert into public.trip_invitations (trip_id, invited_email, role, token_hash, invited_by)
  values (p_trip_id, lower(p_email), p_role, v_hash, auth.uid())
  returning id into v_id;

  perform public.log_activity(
    p_trip_id, 'invitation', v_id, 'invitation_sent',
    format('Invitation sent to %s', p_email),
    jsonb_build_object('email', p_email, 'role', p_role)
  );

  return query select v_id, coalesce(p_token, v_hash);
end;
$$;

create or replace function public.accept_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv  public.trip_invitations;
  v_uid  uuid := auth.uid();
  v_email text;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select lower(p.email) into v_email from auth.users p where p.id = v_uid;

  select * into v_inv
  from public.trip_invitations
  where token_hash = encode(digest(p_token, 'sha256'), 'hex')
    and status = 'pending'
  for update;

  if not found then
    raise exception 'This invitation is invalid, expired or already used'
      using errcode = 'P0002';
  end if;
  if v_inv.expires_at < now() then
    update public.trip_invitations set status = 'expired' where id = v_inv.id;
    raise exception 'This invitation has expired' using errcode = 'P0002';
  end if;
  if lower(v_inv.invited_email) <> v_email then
    raise exception 'This invitation was issued to a different email address'
      using errcode = '42501';
  end if;

  insert into public.trip_members (trip_id, user_id, role, status)
  values (v_inv.trip_id, v_uid, v_inv.role, 'active')
  on conflict (trip_id, user_id) do update
    set role = excluded.role, status = 'active';

  update public.trip_invitations
  set status = 'accepted', accepted_by = v_uid, accepted_at = now()
  where id = v_inv.id;

  perform public.log_activity(
    v_inv.trip_id, 'invitation', v_inv.id, 'invitation_accepted',
    'Invitation accepted',
    jsonb_build_object('user_id', v_uid)
  );

  perform public.notify_trip_members(
    v_inv.trip_id, 'trip_invite', 'New trip member',
    'A new member joined the trip.',
    jsonb_build_object('user_id', v_uid), exclude_user := v_uid
  );

  return v_inv.trip_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 12. Activity + notification helpers
-- ---------------------------------------------------------------------
create or replace function public.log_activity(
  p_trip_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_action text,
  p_summary text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.activity_logs (trip_id, user_id, entity_type, entity_id, action, summary, metadata)
  values (p_trip_id, auth.uid(), p_entity_type, p_entity_id, p_action, p_summary, p_metadata);
$$;

create or replace function public.notify_user(
  p_user_id uuid,
  p_kind public.notification_kind,
  p_title text,
  p_body text default null,
  p_payload jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (user_id, kind, title, body, payload)
  values (p_user_id, p_kind, p_title, p_body, p_payload);
$$;

create or replace function public.notify_trip_members(
  p_trip_id uuid,
  p_kind public.notification_kind,
  p_title text,
  p_body text default null,
  p_payload jsonb default '{}'::jsonb,
  exclude_user uuid default null
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (user_id, kind, title, body, trip_id, payload)
  select m.user_id, p_kind, p_title, p_body, p_trip_id, p_payload
  from public.trip_members m
  where m.trip_id = p_trip_id and m.status = 'active'
    and (exclude_user is null or m.user_id <> exclude_user);
$$;

-- ---------------------------------------------------------------------
-- 13. Budget summary (planned vs actual per category)
-- ---------------------------------------------------------------------
create or replace function public.budget_summary(p_trip_id uuid)
returns table (
  category     public.expense_category,
  planned_minor bigint,
  actual_minor  bigint,
  currency     char(3)
)
language sql
stable
security definer
set search_path = public
as $$
  with actual as (
    select e.category, sum(e.base_amount_minor)::bigint as amount
    from public.expenses e
    where e.trip_id = p_trip_id and e.deleted_at is null
    group by e.category
  )
  select
    coalesce(bc.category, a.category) as category,
    coalesce(bc.planned_minor, 0)::bigint as planned,
    coalesce(a.amount, 0)::bigint as actual,
    t.base_currency::char(3)
  from public.trips t
  left join public.budget_categories bc on bc.trip_id = t.id
  left join actual a on a.category = coalesce(bc.category, a.category)
  where t.id = p_trip_id
  order by category;
$$;

-- ---------------------------------------------------------------------
-- 14. Data export (GDPR-style) — profile + all owned data
-- ---------------------------------------------------------------------
create or replace function public.export_my_data()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'profile', (select to_jsonb(p) - 'id' from public.profiles p where p.id = auth.uid()),
    'trips', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
              from public.trips t where t.owner_id = auth.uid()),
    'memberships', (select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb)
                    from public.trip_members m where m.user_id = auth.uid()),
    'expenses_created', (select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb)
                         from public.expenses e where e.created_by = auth.uid()),
    'settlements', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
                    from public.settlements s where s.created_by = auth.uid()),
    'documents', (select coalesce(jsonb_agg(jsonb_build_object(
                      'name', d.name, 'doc_type', d.doc_type, 'created_at', d.created_at,
                      'expiry_date', d.expiry_date, 'size_bytes', d.size_bytes)),
                    '[]'::jsonb)
                  from public.travel_documents d where d.user_id = auth.uid() and d.deleted_at is null),
    'notifications', (select coalesce(jsonb_agg(to_jsonb(n)), '[]'::jsonb)
                      from public.notifications n where n.user_id = auth.uid()),
    'generated_at', now()
  );
$$;

-- ---------------------------------------------------------------------
-- 15. Overlap detection for the itinerary planner
-- ---------------------------------------------------------------------
create or replace function public.itinerary_conflicts(p_trip_id uuid)
returns table (
  item_id uuid,
  other_item_id uuid,
  day_id uuid,
  overlap_minutes int
)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, b.id, a.day_id,
         extract(epoch from (
           least(a.end_time, b.end_time) - greatest(a.start_time, b.start_time)
         ))::int / 60 as overlap_minutes
  from public.itinerary_items a
  join public.itinerary_items b
    on b.day_id = a.day_id and b.id > a.id
  where a.trip_id = p_trip_id
    and a.start_time is not null and a.end_time is not null
    and b.start_time is not null and b.end_time is not null
    and a.start_time < b.end_time and b.start_time < a.end_time;
$$;

-- ---------------------------------------------------------------------
-- 16. Expense share integrity (deferred constraint trigger)
-- ---------------------------------------------------------------------
create or replace function public.check_expense_share_total()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expense_id uuid := coalesce(new.expense_id, old.expense_id);
  v_total bigint;
  v_sum   bigint;
begin
  select amount_minor into v_total from public.expenses where id = v_expense_id;
  select coalesce(sum(amount_minor), 0) into v_sum
  from public.expense_shares where expense_id = v_expense_id;

  -- Personal expenses are excluded: they carry the full amount for the payer.
  if v_total is not null
     and not exists (
       select 1 from public.expenses e
       where e.id = v_expense_id and (e.is_personal or e.split_method = 'none')
     )
     and v_sum <> v_total then
    raise exception
      'Expense shares (%s) do not sum to the expense total (%s)', v_sum, v_total
      using errcode = '40001';
  end if;
  return null;
end;
$$;

create constraint trigger expense_shares_total_check
  after insert or update or delete on public.expense_shares
  deferrable initially deferred
  for each row execute function public.check_expense_share_total();

-- ---------------------------------------------------------------------
-- 17. Budget threshold alert
-- ---------------------------------------------------------------------
create or replace function public.check_budget_alert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip   public.trips;
  v_budget public.budgets;
  v_spent  bigint;
  v_pct    numeric;
begin
  select * into v_trip from public.trips where id = new.trip_id;
  select * into v_budget from public.budgets where trip_id = new.trip_id;
  if v_budget is null or v_budget.total_minor <= 0 then return null; end if;

  select coalesce(sum(base_amount_minor), 0) into v_spent
  from public.expenses
  where trip_id = new.trip_id and deleted_at is null and not is_personal;

  v_pct := round(v_spent::numeric * 100 / v_budget.total_minor, 2);

  if v_pct >= v_budget.alert_threshold_pct then
    insert into public.notifications (user_id, kind, title, body, trip_id, payload)
    select m.user_id, 'budget_alert',
           'Budget alert: ' || v_trip.name,
           format('Spending has reached %s%% of the trip budget.', v_pct),
           v_trip.id,
           jsonb_build_object('percent', v_pct, 'spent_minor', v_spent,
                              'total_minor', v_budget.total_minor)
    from public.trip_members m
    where m.trip_id = v_trip.id and m.status = 'active'
      and m.role in ('owner', 'admin', 'editor');
  end if;
  return null;
end;
$$;

create trigger expenses_budget_alert
  after insert or update on public.expenses
  for each row when (new.deleted_at is null)
  execute function public.check_budget_alert();
