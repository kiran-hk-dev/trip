-- =====================================================================
-- TripSplit World — 0008 support functions for Edge Functions
-- =====================================================================

-- ---------------------------------------------------------------------
-- Rate limiting. Simple fixed-window counter in Postgres, which is enough for
-- the expensive operations (AI generation, FX proxy, invitations) and needs
-- no extra infrastructure.
-- ---------------------------------------------------------------------
create table if not exists public.rate_limit_buckets (
  bucket      text not null,
  window_start timestamptz not null,
  hits        int not null default 0,
  primary key (bucket, window_start)
);

alter table public.rate_limit_buckets enable row level security;
-- No policies: only the service role (Edge Functions) may touch this table.

create or replace function public.check_rate_limit(
  p_bucket text,
  p_limit int,
  p_window_seconds int
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_window timestamptz := to_timestamp(
    floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds
  );
  v_hits   int;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Rate limiting is only callable by the service role'
      using errcode = '42501';
  end if;

  insert into public.rate_limit_buckets (bucket, window_start, hits)
  values (p_bucket, v_window, 1)
  on conflict (bucket, window_start) do update
    set hits = public.rate_limit_buckets.hits + 1
  returning hits into v_hits;

  return v_hits <= p_limit;
end;
$$;

revoke all on function public.check_rate_limit(text, int, int) from public, anon, authenticated;

-- Opportunistic cleanup so the table does not grow without bound.
create or replace function public.prune_rate_limits()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.rate_limit_buckets
  where window_start < now() - interval '2 days';
$$;

revoke all on function public.prune_rate_limits() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- All trip balances for one user (used by the reminder scheduler).
-- ---------------------------------------------------------------------
create or replace function public.trip_balances_all_for_user(p_user_id uuid)
returns table (
  trip_id    uuid,
  trip_name  text,
  user_id    uuid,
  net_minor  bigint,
  currency   char(3)
)
language sql
stable
security definer
set search_path = public
as $$
  select t.id, t.name, b.user_id, b.net_minor, b.currency
  from public.trip_members m
  join public.trips t on t.id = m.trip_id
  join public.trip_balances(t.id) b on true
  where m.user_id = p_user_id
    and m.status = 'active'
    and t.archived = false;
$$;

revoke all on function public.trip_balances_all_for_user(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Short-lived signed download URLs for private documents.
--
-- The client never receives a public URL and never receives storage
-- credentials. It calls this function (through the caller's RLS context),
-- and the function authorises and signs.
-- ---------------------------------------------------------------------
create or replace function public.create_signed_document_url(
  p_storage_path text,
  p_expires_seconds int default 300
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.travel_documents;
  v_trip uuid;
  v_claims jsonb;
  v_token text;
begin
  v_claims := coalesce(auth.jwt(), '{}'::jsonb);
  v_token := v_claims ->> 'sub';
  if v_token is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select * into v_row
  from public.travel_documents
  where storage_path = p_storage_path and deleted_at is null;

  if not found then
    raise exception 'Document not found' using errcode = 'P0002';
  end if;

  v_trip := v_row.trip_id;

  -- Ownership or trip-admin check.
  if v_row.user_id <> v_token::uuid and not (v_trip is not null and public.can_admin_trip(v_trip)) then
    raise exception 'You do not have access to this document' using errcode = '42501';
  end if;

  -- The path must also sit inside the owner's folder, so a forged path cannot
  -- reach another user's object.
  if split_part(p_storage_path, '/', 1) <> v_row.user_id::text then
    raise exception 'Storage path does not match the document owner' using errcode = '42501';
  end if;

  return storage.create_signed_url(
    'trip-documents', p_storage_path, least(greatest(p_expires_seconds, 60), 900)
  );
end;
$$;

grant execute on function public.create_signed_document_url(text, int) to authenticated;

create or replace function public.create_signed_receipt_url(
  p_storage_path text,
  p_expires_seconds int default 300
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expenses public.expenses;
  v_claims jsonb;
  v_token text;
begin
  v_claims := coalesce(auth.jwt(), '{}'::jsonb);
  v_token := v_claims ->> 'sub';
  if v_token is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select * into v_expenses
  from public.expenses where receipt_path = p_storage_path;

  if not found then
    raise exception 'Receipt not found' using errcode = 'P0002';
  end if;

  -- Receipts belong to whoever can see the expense.
  if not public.is_trip_member(v_expenses.trip_id) then
    raise exception 'You do not have access to this receipt' using errcode = '42501';
  end if;

  if split_part(p_storage_path, '/', 1) <> v_expenses.created_by::text then
    raise exception 'Storage path does not match the uploader' using errcode = '42501';
  end if;

  return storage.create_signed_url(
    'trip-receipts', p_storage_path, least(greatest(p_expires_seconds, 60), 900)
  );
end;
$$;

grant execute on function public.create_signed_receipt_url(text, int) to authenticated;

-- ---------------------------------------------------------------------
-- Trip dashboard summary — one round trip for the home screen.
-- ---------------------------------------------------------------------
create or replace function public.dashboard_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_next_trip uuid;
  v_result jsonb;
  v_budget bigint;
  v_spent bigint;
  v_owed_to_me bigint;
  v_i_owe bigint;
  v_currency char(3);
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select t.id into v_next_trip
  from public.trips t
  join public.trip_members m on m.trip_id = t.id and m.user_id = v_user and m.status = 'active'
  where t.archived = false
    and t.end_date >= current_date
  order by t.start_date asc
  limit 1;

  if v_next_trip is not null then
    select base_currency into v_currency from public.trips where id = v_next_trip;
    select coalesce(sum(base_amount_minor), 0) into v_spent
    from public.expenses where trip_id = v_next_trip and deleted_at is null;
    select coalesce(max(total_minor), 0) into v_budget
    from public.budgets where trip_id = v_next_trip;
  else
    -- No trip context: fall back to the app's default currency.
    v_currency := 'INR';
  end if;

  -- Net position across every active trip, expressed in each trip's own
  -- currency. The client groups by currency rather than pretending they add up.
  with mine as (
    select t.id as trip_id, t.base_currency, t.name,
           coalesce(b.net_minor, 0) as net_minor
    from public.trips t
    join public.trip_members m on m.trip_id = t.id and m.user_id = v_user and m.status = 'active'
    left join public.trip_balances(t.id) b on b.user_id = v_user
    where t.archived = false
  )
  select
    coalesce(sum(net_minor) filter (where net_minor > 0), 0),
    coalesce(sum(-net_minor) filter (where net_minor < 0), 0)
  into v_owed_to_me, v_i_owe
  from mine;

  v_result := jsonb_build_object(
    'next_trip_id', v_next_trip,
    'planned_budget_minor', v_budget,
    'spent_minor', coalesce(v_spent, 0),
    'currency', v_currency,
    'owed_to_me_minor', v_owed_to_me,
    'i_owe_minor', v_i_owe
  );

  return v_result;
end;
$$;

grant execute on function public.dashboard_summary() to authenticated;

-- ---------------------------------------------------------------------
-- Convenience RPC used by the expenses list screen for filtering + sorting
-- without shipping a large join to the client.
-- ---------------------------------------------------------------------
create or replace function public.list_trip_expenses(
  p_trip_id uuid,
  p_category public.expense_category default null,
  p_paid_by uuid default null,
  p_participant uuid default null,
  p_from_date date default null,
  p_to_date date default null,
  p_search text default null,
  p_limit int default 50,
  p_offset int default 0,
  p_sort text default 'date_desc'
)
returns table (
  id uuid,
  title text,
  amount_minor bigint,
  currency char(3),
  base_amount_minor bigint,
  category public.expense_category,
  expense_date date,
  paid_by uuid,
  split_method public.split_method,
  is_personal boolean,
  notes text,
  receipt_path text,
  fx_rate numeric,
  fx_provider text,
  fx_fetched_at timestamptz,
  my_share_minor bigint,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_trip_member(p_trip_id) then
    raise exception 'Not a member of this trip' using errcode = '42501';
  end if;

  return query
  select
    e.id, e.title, e.amount_minor, e.currency, e.base_amount_minor,
    e.category, e.expense_date, e.paid_by, e.split_method, e.is_personal,
    e.notes, e.receipt_path, e.fx_rate, e.fx_provider, e.fx_fetched_at,
    coalesce((select s.base_amount_minor from public.expense_shares s
              where s.expense_id = e.id and s.user_id = auth.uid()), 0),
    e.created_at
  from public.expenses e
  where e.trip_id = p_trip_id
    and e.deleted_at is null
    and (p_category is null or e.category = p_category)
    and (p_paid_by is null or e.paid_by = p_paid_by)
    and (p_from_date is null or e.expense_date >= p_from_date)
    and (p_to_date is null or e.expense_date <= p_to_date)
    and (p_search is null or e.title ilike '%' || p_search || '%'
         or coalesce(e.notes, '') ilike '%' || p_search || '%')
    and (p_participant is null or e.participant_ids @> ARRAY[p_participant])
  order by
    case when p_sort = 'date_asc'    then e.expense_date end asc nulls last,
    case when p_sort = 'amount_asc'  then e.amount_minor end asc nulls last,
    case when p_sort = 'amount_desc' then e.amount_minor end desc nulls last,
    case when p_sort = 'category'    then e.category::text end asc nulls last,
    e.expense_date desc,
    e.created_at desc
  limit least(greatest(p_limit, 1), 200)
  offset greatest(p_offset, 0);
end;
$$;

grant execute on function
  public.list_trip_expenses(uuid, public.expense_category, uuid, uuid, date, date, text, int, int, text)
  to authenticated;
