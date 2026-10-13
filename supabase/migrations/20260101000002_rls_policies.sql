-- =====================================================================
-- TripSplit World — 0002 Row Level Security
--
-- Design rules:
--   * Every table that holds user or trip data has RLS enabled.
--   * Access to trip data always resolves through trip_members.
--   * Role helpers are SECURITY DEFINER STABLE so they do not recurse.
--   * Public reference data (emergency, visa links, advisories) has an
--     explicit anonymous SELECT policy and is kept in separate tables from
--     private trip data so a broad policy can never leak a document.
-- =====================================================================

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;

create policy "profiles: read own"
  on public.profiles for select using (id = auth.uid());

-- Trip collaborators need display names for member lists.
create policy "profiles: read co-members"
  on public.profiles for select using (
    exists (
      select 1 from public.trip_members me
      join public.trip_members them on them.trip_id = me.trip_id
      where me.user_id = auth.uid() and me.status = 'active'
        and them.user_id = profiles.id and them.status = 'active'
    )
  );

create policy "profiles: insert own"
  on public.profiles for insert with check (id = auth.uid());

create policy "profiles: update own"
  on public.profiles for update using (id = auth.uid())
  with check (id = auth.uid());

-- A user may delete only their own profile (cascades to their trips).

-- ---------------------------------------------------------------------
-- trips
-- ---------------------------------------------------------------------
alter table public.trips enable row level security;

create policy "trips: members read"
  on public.trips for select using (public.is_trip_member(id));

create policy "trips: authenticated read shared"
  on public.trips for select using (visibility = 'shared' and auth.uid() is not null);

create policy "trips: create own"
  on public.trips for insert with check (owner_id = auth.uid());

create policy "trips: admin update"
  on public.trips for update using (public.can_admin_trip(id))
  with check (public.can_admin_trip(id));

create policy "trips: owner delete"
  on public.trips for delete using (owner_id = auth.uid());

-- ---------------------------------------------------------------------
-- trip_members
-- ---------------------------------------------------------------------
alter table public.trip_members enable row level security;

create policy "trip_members: members read"
  on public.trip_members for select using (public.is_trip_member(trip_id));

-- The owner is inserted by a trigger on trips (SECURITY DEFINER), so no
-- INSERT policy is exposed to clients.
create policy "trip_members: admin manage"
  on public.trip_members for all
  using (public.can_admin_trip(trip_id))
  with check (public.can_admin_trip(trip_id));

-- A member may always leave a trip they are in.
create policy "trip_members: self remove"
  on public.trip_members for delete using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- trip_invitations
-- ---------------------------------------------------------------------
alter table public.trip_invitations enable row level security;

-- Admins of the trip manage invitations.
create policy "invitations: admins manage"
  on public.trip_invitations for all
  using (public.can_admin_trip(trip_id))
  with check (public.can_admin_trip(trip_id));

-- The recipient may read their own invitation by email.
create policy "invitations: recipient read"
  on public.trip_invitations for select using (
    lower(invited_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Acceptance goes through the accept_invitation() function only.

-- ---------------------------------------------------------------------
-- trip_destinations
-- ---------------------------------------------------------------------
alter table public.trip_destinations enable row level security;
create policy "destinations_of_trip: members all"
  on public.trip_destinations for all
  using (public.is_trip_member(trip_id))
  with check (public.is_trip_member(trip_id));

-- ---------------------------------------------------------------------
-- itinerary
-- ---------------------------------------------------------------------
alter table public.itinerary_days enable row level security;
alter table public.itinerary_items enable row level security;

create policy "itinerary_days: members read"
  on public.itinerary_days for select using (public.is_trip_member(trip_id));

create policy "itinerary_days: editors write"
  on public.itinerary_days for all
  using (public.can_edit_trip(trip_id))
  with check (public.can_edit_trip(trip_id));

create policy "itinerary_items: members read"
  on public.itinerary_items for select using (public.is_trip_member(trip_id));

create policy "itinerary_items: editors write"
  on public.itinerary_items for all
  using (public.can_edit_trip(trip_id))
  with check (public.can_edit_trip(trip_id));

-- ---------------------------------------------------------------------
-- budgets
-- ---------------------------------------------------------------------
alter table public.budgets enable row level security;
alter table public.budget_categories enable row level security;

create policy "budgets: members read"
  on public.budgets for select using (public.is_trip_member(trip_id));

create policy "budgets: editors write"
  on public.budgets for all
  using (public.can_edit_trip(trip_id))
  with check (public.can_edit_trip(trip_id));

create policy "budget_categories: members read"
  on public.budget_categories for select using (public.is_trip_member(trip_id));

create policy "budget_categories: editors write"
  on public.budget_categories for all
  using (public.can_edit_trip(trip_id))
  with check (public.can_edit_trip(trip_id));

-- ---------------------------------------------------------------------
-- expenses
-- ---------------------------------------------------------------------
alter table public.expenses enable row level security;

-- Any trip member can see a trip expense (itinerary/budget transparency).
create policy "expenses: members read"
  on public.expenses for select using (public.is_trip_member(trip_id));

-- Editors and above may add shared expenses.
create policy "expenses: editors insert"
  on public.expenses for insert with check (
    public.can_edit_trip(trip_id)
    and exists (select 1 from public.profiles p where p.id = auth.uid())
  );

-- A member may always edit or delete an expense they personally created,
-- even as a plain editor, so mistakes are self-correctable.
create policy "expenses: creators mutate"
  on public.expenses for update
  using (created_by = auth.uid() or public.can_admin_trip(trip_id))
  with check (created_by = auth.uid() or public.can_admin_trip(trip_id));

create policy "expenses: creators delete"
  on public.expenses for delete
  using (created_by = auth.uid() or public.can_admin_trip(trip_id));

-- ---------------------------------------------------------------------
-- expense participants + shares
-- ---------------------------------------------------------------------
alter table public.expense_participants enable row level security;
alter table public.expense_shares enable row level security;

create policy "expense_participants: members read"
  on public.expense_participants for select using (public.is_trip_member(trip_id));

create policy "expense_shares: members read"
  on public.expense_shares for select using (public.is_trip_member(trip_id));

-- Shares are written only by the create_expense / update_expense functions,
-- which recompute them server-side. No direct insert policy is granted.

-- ---------------------------------------------------------------------
-- settlements
-- ---------------------------------------------------------------------
alter table public.settlements enable row level security;
alter table public.settlement_allocations enable row level security;

create policy "settlements: members read"
  on public.settlements for select using (public.is_trip_member(trip_id));

-- Recording a settlement goes through record_settlement(), which validates
-- the amount against live balances. Direct writes are denied.
create policy "settlements: creators delete"
  on public.settlements for delete
  using (created_by = auth.uid() and public.can_edit_trip(trip_id));

create policy "settlement_allocations: members read"
  on public.settlement_allocations for select using (public.is_trip_member(trip_id));

-- ---------------------------------------------------------------------
-- exchange rates + conversion history
-- ---------------------------------------------------------------------
alter table public.exchange_rates enable row level security;
alter table public.currency_conversion_history enable row level security;

-- Reference data: readable by anyone, writable only by service role.
create policy "exchange_rates: public read"
  on public.exchange_rates for select using (true);

create policy "conversion_history: own"
  on public.currency_conversion_history for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- bookings
-- ---------------------------------------------------------------------
alter table public.bookings enable row level security;
create policy "bookings: members read"
  on public.bookings for select using (public.is_trip_member(trip_id));
create policy "bookings: editors write"
  on public.bookings for all
  using (public.can_edit_trip(trip_id))
  with check (public.can_edit_trip(trip_id));

-- ---------------------------------------------------------------------
-- travel documents — strictly owner + trip admins
-- ---------------------------------------------------------------------
alter table public.travel_documents enable row level security;

create policy "documents: owner read"
  on public.travel_documents for select
  using (user_id = auth.uid() or (trip_id is not null and public.can_admin_trip(trip_id)));

create policy "documents: owner insert"
  on public.travel_documents for insert with check (user_id = auth.uid());

create policy "documents: owner mutate"
  on public.travel_documents for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "documents: owner delete"
  on public.travel_documents for delete using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- packing lists — shared with the trip, editable by editors
-- ---------------------------------------------------------------------
alter table public.packing_lists enable row level security;
alter table public.packing_list_items enable row level security;

create policy "packing_lists: members read"
  on public.packing_lists for select
  using (owner_id = auth.uid() or (trip_id is not null and public.is_trip_member(trip_id)));

create policy "packing_lists: owner write"
  on public.packing_lists for all
  using (owner_id = auth.uid() or (trip_id is not null and public.can_edit_trip(trip_id)))
  with check (owner_id = auth.uid() or (trip_id is not null and public.can_edit_trip(trip_id)));

create policy "packing_items: read"
  on public.packing_list_items for select using (
    exists (
      select 1 from public.packing_lists l
      where l.id = packing_list_items.list_id
        and (l.owner_id = auth.uid()
             or (l.trip_id is not null and public.is_trip_member(l.trip_id)))
    )
  );

create policy "packing_items: write"
  on public.packing_list_items for all
  using (
    exists (
      select 1 from public.packing_lists l
      where l.id = packing_list_items.list_id
        and (l.owner_id = auth.uid()
             or (l.trip_id is not null and public.can_edit_trip(l.trip_id)))
    )
  )
  with check (
    exists (
      select 1 from public.packing_lists l
      where l.id = packing_list_items.list_id
        and (l.owner_id = auth.uid()
             or (l.trip_id is not null and public.can_edit_trip(l.trip_id)))
    )
  );

-- ---------------------------------------------------------------------
-- visa records, insurance
-- ---------------------------------------------------------------------
alter table public.visa_records enable row level security;
create policy "visa_records: members"
  on public.visa_records for all
  using (public.is_trip_member(trip_id))
  with check (public.can_edit_trip(trip_id));

alter table public.insurance_policies enable row level security;
create policy "insurance: owner"
  on public.insurance_policies for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- saved destinations
-- ---------------------------------------------------------------------
alter table public.saved_destinations enable row level security;
create policy "saved_destinations: own"
  on public.saved_destinations for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- public reference catalogue
-- ---------------------------------------------------------------------
alter table public.destinations enable row level security;
create policy "destinations: public read"
  on public.destinations for select using (true);

-- ---------------------------------------------------------------------
-- notifications + activity
-- ---------------------------------------------------------------------
alter table public.notifications enable row level security;
create policy "notifications: own"
  on public.notifications for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

alter table public.activity_logs enable row level security;
create policy "activity_logs: members read"
  on public.activity_logs for select using (trip_id is null or public.is_trip_member(trip_id));
create policy "activity_logs: members write"
  on public.activity_logs for insert
  with check (auth.uid() is not null and (trip_id is null or public.is_trip_member(trip_id)));

-- ---------------------------------------------------------------------
-- PUBLIC emergency / visa / advisory reference data.
-- Kept in dedicated tables so an anonymous SELECT policy here can never be
-- widened into private trip data.
-- ---------------------------------------------------------------------
alter table public.emergency_resources enable row level security;
create policy "emergency_resources: public read"
  on public.emergency_resources for select using (true);

alter table public.emergency_guides enable row level security;
create policy "emergency_guides: public read"
  on public.emergency_guides for select using (true);

alter table public.visa_resource_links enable row level security;
create policy "visa_resource_links: public read"
  on public.visa_resource_links for select using (true);

alter table public.travel_advisories enable row level security;
create policy "travel_advisories: public read"
  on public.travel_advisories for select using (true);

alter table public.source_verification_log enable row level security;
-- Not client-readable; only the service role (Edge Functions) touches it.

-- ---------------------------------------------------------------------
-- generation jobs + offline queue
-- ---------------------------------------------------------------------
alter table public.itinerary_generation_jobs enable row level security;
create policy "generation_jobs: own read"
  on public.itinerary_generation_jobs for select using (user_id = auth.uid());

alter table public.offline_queue enable row level security;
create policy "offline_queue: own"
  on public.offline_queue for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
