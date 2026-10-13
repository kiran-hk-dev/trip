-- =====================================================================
-- TripSplit World — 0007 function grants
--
-- Default-deny: only explicitly granted functions are executable.
-- The *_internal / *_as / bootstrap helpers used by the demo seed are revoked
-- from anon and authenticated so they cannot be called by a client.
-- =====================================================================

revoke all on function public.create_expense_internal(uuid, uuid, text, bigint, char, public.expense_category, date, uuid, public.split_method, uuid[], jsonb, jsonb, jsonb, boolean, text, text, bigint, numeric, text) from public, anon, authenticated;
revoke all on function public.record_settlement_internal(uuid, uuid, uuid, uuid, bigint, char, public.settlement_method, text, text, date, bigint, numeric, text, text) from public, anon, authenticated;
revoke all on function public.create_expense_as(uuid, text, bigint, char, char, bigint, public.expense_category, uuid, public.split_method, uuid[], jsonb, jsonb, jsonb, boolean, text) from public, anon, authenticated;
revoke all on function public.record_settlement_as(uuid, uuid, uuid, bigint, char, public.settlement_method, text, text, date, uuid) from public, anon, authenticated;
revoke all on function public.seed_demo_trip() from public, anon, authenticated;
revoke all on function public.bootstrap_trip_owner() from public, anon, authenticated;
revoke all on function public.normalise_expense_base_shares(uuid, bigint) from public, anon, authenticated;
revoke all on function public.confirm_settlement(uuid, text, text) from public, anon, authenticated;
revoke all on function public.sync_itinerary_days() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.check_expense_share_total() from public, anon, authenticated;
revoke all on function public.check_budget_alert() from public, anon, authenticated;
revoke all on function public.touch_updated_at() from public, anon, authenticated;

-- Client-callable API surface.
grant execute on function public.create_expense(uuid, text, bigint, char, public.expense_category, date, uuid, public.split_method, uuid[], jsonb, jsonb, jsonb, boolean, text, text, bigint, numeric, text) to authenticated;
grant execute on function public.update_expense(uuid, text, bigint, char, bigint, numeric, text, public.expense_category, date, uuid, public.split_method, uuid[], jsonb, jsonb, jsonb, text, text) to authenticated;
grant execute on function public.delete_expense(uuid) to authenticated;
grant execute on function public.trip_balances(uuid) to authenticated;
grant execute on function public.suggest_settlements(uuid) to authenticated;
grant execute on function public.record_settlement(uuid, uuid, uuid, bigint, char, public.settlement_method, text, text, date, bigint, numeric, text, text) to authenticated;
grant execute on function public.budget_summary(uuid) to authenticated;
grant execute on function public.itinerary_conflicts(uuid) to authenticated;
grant execute on function public.create_invitation(uuid, text, public.trip_role, text) to authenticated;
grant execute on function public.accept_invitation(text) to authenticated;
grant execute on function public.copy_template_list(text, text, uuid, boolean) to authenticated;
grant execute on function public.export_my_data() to authenticated;

-- Emergency reference data is public and deliberately reachable anonymously so
-- the Emergency Center works without an account.
grant usage on schema public to anon, authenticated;
grant select on public.emergency_resources to anon, authenticated;
grant select on public.emergency_guides to anon, authenticated;
grant select on public.visa_resource_links to anon, authenticated;
grant select on public.travel_advisories to anon, authenticated;
grant select on public.destinations to anon, authenticated;
grant select on public.checklist_templates to anon, authenticated;

-- Table grants mirror the RLS policies above: RLS is the real gate, these
-- grants simply stop the error before the policy is evaluated.
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Profiles must never be fully readable at the table level even though RLS
-- filters rows, so that a policy mistake cannot leak a whole table.
revoke select on public.profiles from anon;

-- Guard against accidental writes to reference tables from a client.
revoke insert, update, delete on public.emergency_resources from anon, authenticated;
revoke insert, update, delete on public.emergency_guides from anon, authenticated;
revoke insert, update, delete on public.visa_resource_links from anon, authenticated;
revoke insert, update, delete on public.travel_advisories from anon, authenticated;
revoke insert, update, delete on public.destinations from anon, authenticated;
revoke insert, update, delete on public.checklist_templates from anon, authenticated;
revoke all on public.source_verification_log from anon, authenticated;
