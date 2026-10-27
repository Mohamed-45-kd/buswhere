-- Table access for the app's roles. Row level security (core migration) still
-- decides which rows each person may see or change; these grants only open the door.
grant usage on schema public to anon, authenticated;

grant select on public.cities, public.districts, public.villages, public.stops, public.buses,
  public.bus_live, public.waiting_counts to anon, authenticated;

-- Admin edits (RLS allows admins only).
grant insert, update, delete on public.cities, public.districts, public.villages, public.stops, public.buses to authenticated;

-- Own rows only (RLS), or admin.
grant select on public.village_assignments, public.trips, public.position_samples, public.waiting_requests, public.admins to authenticated;
