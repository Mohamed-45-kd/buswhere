-- App actions. Every write by riders and drivers goes through these functions,
-- so the rules from the product doc are enforced in one place.

-- ───────────────────────── riders
-- "Waan sugayaa": one active request per device, 15-minute expiry, rate limited.
create or replace function public.start_waiting(p_village text, p_destination text, p_stop text)
returns public.waiting_requests
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  r public.waiting_requests;
begin
  if uid is null then raise exception 'not-signed-in'; end if;
  if p_village = p_destination then raise exception 'same-village'; end if;
  if not exists (select 1 from public.stops s join public.villages v on v.id = s.village_id
                 where s.id = p_stop and s.village_id = p_village and v.is_active) then
    raise exception 'bad-stop';
  end if;
  if not exists (select 1 from public.villages where id = p_destination and is_active) then
    raise exception 'bad-destination';
  end if;
  if (select count(*) from public.waiting_requests where rider_uid = uid and created_at > now() - interval '1 hour') >= 12 then
    raise exception 'rate-limit';
  end if;
  update public.waiting_requests set status = 'cancelled', ended_at = now() where rider_uid = uid and status = 'waiting';
  insert into public.waiting_requests (rider_uid, village_id, destination_village_id, stop_id)
  values (uid, p_village, p_destination, p_stop) returning * into r;
  return r;
end $$;

-- "Waan fuulay" (boarded = true) or stop waiting.
create or replace function public.stop_waiting(p_boarded boolean default false)
returns void
language sql security definer set search_path = public as $$
  update public.waiting_requests
  set status = case when p_boarded then 'boarded' else 'cancelled' end, ended_at = now()
  where rider_uid = auth.uid() and status = 'waiting';
$$;

-- ───────────────────────── drivers
create or replace function public.current_driver() returns public.drivers
language sql stable security definer set search_path = public as $$
  select * from public.drivers where auth_uid = auth.uid() and auth.uid() is not null limit 1;
$$;

-- Sign a device in as a driver with phone + PIN. Five wrong PINs lock the
-- account for 15 minutes. Returns {error} instead of raising so the attempt
-- counter is kept.
create or replace function public.driver_sign_in(p_phone text, p_pin text)
returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  d public.drivers;
begin
  if auth.uid() is null then return json_build_object('error', 'not-signed-in'); end if;
  select * into d from public.drivers where phone = public.norm_phone(p_phone);
  if not found then
    perform pg_sleep(0.4);
    return json_build_object('error', 'bad-login');
  end if;
  if d.locked_until is not null and d.locked_until > now() then
    return json_build_object('error', 'locked', 'until', d.locked_until);
  end if;
  if d.pin_hash <> crypt(coalesce(p_pin, ''), d.pin_hash) then
    update public.drivers
    set failed_attempts = failed_attempts + 1,
        locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' end
    where id = d.id;
    return json_build_object('error', 'bad-login');
  end if;
  if not d.approved then return json_build_object('error', 'not-approved'); end if;
  if d.bus_id is null then return json_build_object('error', 'no-bus'); end if;
  update public.drivers set auth_uid = null where auth_uid = auth.uid() and id <> d.id;
  update public.drivers set auth_uid = auth.uid(), failed_attempts = 0, locked_until = null where id = d.id;
  return json_build_object('id', d.id);
end $$;

create or replace function public.driver_sign_out() returns void
language sql security definer set search_path = public as $$
  update public.drivers set auth_uid = null where auth_uid = auth.uid();
$$;

-- Driver's own profile, bus and active village.
create or replace function public.driver_me() returns json
language sql stable security definer set search_path = public as $$
  select case when d.id is null then null else json_build_object(
    'id', d.id, 'name', d.name, 'phone', d.phone, 'approved', d.approved,
    'bus', (select json_build_object('id', b.id, 'number', b.number, 'plate', b.plate) from public.buses b where b.id = d.bus_id),
    'assignment', (select json_build_object('id', a.id, 'village_id', a.village_id, 'destination_village_id', a.destination_village_id, 'started_at', a.started_at)
                   from public.village_assignments a where a.driver_id = d.id and a.ended_at is null),
    'live', (select json_build_object('online', l.online, 'full', l.is_full, 'updated_at', l.updated_at) from public.bus_live l where l.driver_id = d.id)
  ) end
  from (select (public.current_driver()).*) d;
$$;

-- Join one village and go live. Refuses a second active village.
create or replace function public.driver_assign(p_village text, p_destination text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  d public.drivers := public.current_driver();
  a_id uuid;
begin
  if d.id is null or not d.approved then raise exception 'not-a-driver'; end if;
  if d.bus_id is null then raise exception 'no-bus'; end if;
  if p_village = p_destination then raise exception 'same-village'; end if;
  if not exists (select 1 from public.villages where id = p_village and is_active)
     or not exists (select 1 from public.villages where id = p_destination and is_active) then
    raise exception 'bad-village';
  end if;
  if exists (select 1 from public.village_assignments where driver_id = d.id and ended_at is null) then
    raise exception 'already-active';
  end if;
  insert into public.village_assignments (driver_id, village_id, destination_village_id)
  values (d.id, p_village, p_destination) returning id into a_id;
  insert into public.trips (assignment_id, driver_id, village_id, destination_village_id) values (a_id, d.id, p_village, p_destination);
  insert into public.bus_live (bus_id, driver_id, assignment_id, driver_name, bus_number, village_id, destination_village_id)
  select d.bus_id, d.id, a_id, d.name, b.number, p_village, p_destination from public.buses b where b.id = d.bus_id
  on conflict (bus_id) do update set driver_id = excluded.driver_id, assignment_id = excluded.assignment_id,
    driver_name = excluded.driver_name, bus_number = excluded.bus_number, village_id = excluded.village_id,
    destination_village_id = excluded.destination_village_id, online = true, is_full = false, updated_at = now();
  return a_id;
end $$;

-- New trip from the same village: change where the bus is heading.
create or replace function public.driver_change_destination(p_destination text) returns void
language plpgsql security definer set search_path = public as $$
declare
  d public.drivers := public.current_driver();
  a public.village_assignments;
begin
  select * into a from public.village_assignments where driver_id = d.id and ended_at is null;
  if a.id is null then raise exception 'not-active'; end if;
  if a.village_id = p_destination then raise exception 'same-village'; end if;
  update public.village_assignments set destination_village_id = p_destination where id = a.id;
  update public.bus_live set destination_village_id = p_destination, is_full = false, updated_at = now() where driver_id = d.id;
  insert into public.trips (assignment_id, driver_id, village_id, destination_village_id) values (a.id, d.id, a.village_id, p_destination);
end $$;

create or replace function public.end_assignment(p_driver uuid, p_reason text) returns void
language sql security definer set search_path = public as $$
  update public.village_assignments set ended_at = now(), end_reason = p_reason where driver_id = p_driver and ended_at is null;
  delete from public.bus_live where driver_id = p_driver;
$$;
revoke execute on function public.end_assignment(uuid, text) from public, anon, authenticated;

create or replace function public.driver_withdraw() returns void
language plpgsql security definer set search_path = public as $$
declare d public.drivers := public.current_driver();
begin
  if d.id is null then raise exception 'not-a-driver'; end if;
  perform public.end_assignment(d.id, 'driver');
end $$;

-- GPS every ~10 s. Saves a report sample every 30 s.
create or replace function public.driver_ping(p_lat double precision, p_lng double precision, p_speed double precision default null, p_heading double precision default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  d public.drivers := public.current_driver();
  l public.bus_live;
begin
  if d.id is null then raise exception 'not-a-driver'; end if;
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'bad-position'; end if;
  update public.bus_live set lat = p_lat, lng = p_lng, speed = p_speed, heading = p_heading, online = true, updated_at = now()
  where driver_id = d.id returning * into l;
  if l.bus_id is null then raise exception 'not-active'; end if;
  if l.last_sample_at is null or l.last_sample_at < now() - interval '30 seconds' then
    insert into public.position_samples (bus_id, driver_id, village_id, lat, lng) values (l.bus_id, d.id, l.village_id, p_lat, p_lng);
    update public.bus_live set last_sample_at = now() where bus_id = l.bus_id;
  end if;
end $$;

create or replace function public.driver_set_status(p_online boolean default null, p_full boolean default null) returns void
language plpgsql security definer set search_path = public as $$
declare d public.drivers := public.current_driver();
begin
  if d.id is null then raise exception 'not-a-driver'; end if;
  update public.bus_live set online = coalesce(p_online, online), is_full = coalesce(p_full, is_full), updated_at = now() where driver_id = d.id;
end $$;

-- Driver tapped a stop after picking riders up there.
create or replace function public.driver_pick_up(p_stop text) returns int
language plpgsql security definer set search_path = public as $$
declare
  d public.drivers := public.current_driver();
  a public.village_assignments;
  n int;
begin
  select * into a from public.village_assignments where driver_id = d.id and ended_at is null;
  if a.id is null then raise exception 'not-active'; end if;
  update public.waiting_requests set status = 'picked', ended_at = now()
  where stop_id = p_stop and village_id = a.village_id and destination_village_id = a.destination_village_id and status = 'waiting';
  get diagnostics n = row_count;
  return n;
end $$;

-- ───────────────────────── admin
create or replace function public.admin_save_driver(p_id uuid, p_name text, p_phone text, p_pin text, p_bus uuid, p_approved boolean)
returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare r uuid;
begin
  if not public.is_admin() then raise exception 'not-admin'; end if;
  if p_pin is not null and p_pin !~ '^\d{4,6}$' then raise exception 'bad-pin'; end if;
  if length(public.norm_phone(p_phone)) < 7 then raise exception 'bad-phone'; end if;
  -- A bus belongs to one driver: unlink it from anyone else first.
  if p_bus is not null then update public.drivers set bus_id = null where bus_id = p_bus and id is distinct from p_id; end if;
  if p_id is null then
    if p_pin is null then raise exception 'bad-pin'; end if;
    insert into public.drivers (name, phone, pin_hash, bus_id, approved)
    values (trim(p_name), public.norm_phone(p_phone), crypt(p_pin, gen_salt('bf')), p_bus, coalesce(p_approved, true))
    returning id into r;
  else
    update public.drivers set name = trim(p_name), phone = public.norm_phone(p_phone), bus_id = p_bus,
      approved = coalesce(p_approved, approved),
      pin_hash = case when p_pin is null then pin_hash else crypt(p_pin, gen_salt('bf')) end,
      failed_attempts = case when p_pin is null then failed_attempts else 0 end,
      locked_until = case when p_pin is null then locked_until end,
      -- A new PIN or turning approval off signs the driver's device out.
      auth_uid = case when p_pin is not null or p_approved = false then null else auth_uid end
    where id = p_id returning id into r;
    if p_approved = false or p_bus is null then perform public.end_assignment(p_id, 'admin'); end if;
  end if;
  return r;
end $$;

create or replace function public.admin_withdraw_driver(p_driver uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not-admin'; end if;
  perform public.end_assignment(p_driver, 'admin');
end $$;

-- Reports, in Hargeisa time.
create or replace function public.admin_report() returns json
language plpgsql stable security definer set search_path = public as $$
declare
  tz text := 'Africa/Mogadishu';
  today date := (now() at time zone tz)::date;
begin
  if not public.is_admin() then raise exception 'not-admin'; end if;
  return json_build_object(
    'trips_today', (select count(*) from public.trips where (started_at at time zone tz)::date = today),
    'waits_today', (select count(*) from public.waiting_requests where (created_at at time zone tz)::date = today),
    'waits_by_hour', (select json_agg(coalesce(c, 0) order by h) from generate_series(0, 23) h
                      left join (select extract(hour from created_at at time zone tz)::int hh, count(*) c
                                 from public.waiting_requests where (created_at at time zone tz)::date = today group by 1) x on x.hh = h),
    'busiest_villages', (select coalesce(json_agg(json_build_object('village_id', village_id, 'n', n) order by n desc), '[]'::json)
                         from (select village_id, count(*) n from public.waiting_requests
                               where created_at > now() - interval '7 days' group by 1 order by 2 desc limit 8) b),
    'picked_up_today', (select count(*) from public.waiting_requests where status in ('picked', 'boarded') and (created_at at time zone tz)::date = today)
  );
end $$;

-- ───────────────────────── housekeeping (every minute)
-- Expire waits after 15 minutes; withdraw drivers silent for 30 minutes so
-- riders never see a bus that is not there.
create or replace function public.housekeeping() returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  update public.waiting_requests set status = 'expired', ended_at = now() where status = 'waiting' and expires_at <= now();
  for r in select driver_id from public.bus_live where updated_at < now() - interval '30 minutes' loop
    perform public.end_assignment(r.driver_id, 'auto-offline');
  end loop;
  delete from public.position_samples where at < now() - interval '90 days';
end $$;
revoke execute on function public.housekeeping() from public, anon, authenticated;

select cron.schedule('buswhere-housekeeping', '* * * * *', $$select public.housekeeping()$$);

-- Internal helpers are not part of the API.
revoke execute on function public.current_driver() from public, anon, authenticated;
revoke execute on function public.refresh_waiting_count(text, text, text) from public, anon, authenticated;
