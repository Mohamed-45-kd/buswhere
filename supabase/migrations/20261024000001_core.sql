-- BusWhere pilot schema. Mirrors the product doc's eight tables (+ districts),
-- with bus_live standing in for Redis (one row per bus on the road) and
-- waiting_counts holding the live "N waiting" numbers riders and drivers see.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_cron;

-- ───────────────────────── places
create table public.cities (
  id text primary key,
  name_so text not null,
  name_en text not null,
  is_active boolean not null default true,
  sort int not null default 0
);

create table public.districts (
  id text primary key,
  city_id text not null references public.cities on delete cascade,
  name text not null,
  is_active boolean not null default true,
  sort int not null default 0
);

create table public.villages (
  id text primary key default gen_random_uuid()::text,
  district_id text not null references public.districts on delete cascade,
  name_so text not null,
  name_en text not null,
  lat double precision not null,
  lng double precision not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.stops (
  id text primary key default gen_random_uuid()::text,
  village_id text not null references public.villages on delete cascade,
  name text not null,
  sub text,
  lat double precision not null,
  lng double precision not null,
  sort int not null default 0
);
create index on public.stops (village_id);

-- ───────────────────────── fleet
create table public.buses (
  id uuid primary key default gen_random_uuid(),
  number int not null unique,
  plate text not null,
  capacity int not null default 14,
  owner text not null default '',
  status text not null default 'active'
);

-- One driver, one bus. PINs are bcrypt-hashed; auth_uid is the device session
-- that last signed in with the right PIN.
create table public.drivers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null unique,
  pin_hash text not null,
  bus_id uuid unique references public.buses on delete set null,
  approved boolean not null default true,
  auth_uid uuid unique,
  failed_attempts int not null default 0,
  locked_until timestamptz,
  created_at timestamptz not null default now()
);

-- ended_at empty = active now; at most one active row per driver.
create table public.village_assignments (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers on delete cascade,
  village_id text not null references public.villages on delete cascade,
  destination_village_id text not null references public.villages on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  end_reason text
);
create unique index one_active_assignment on public.village_assignments (driver_id) where ended_at is null;

create table public.trips (
  id bigserial primary key,
  assignment_id uuid references public.village_assignments on delete cascade,
  driver_id uuid references public.drivers on delete cascade,
  village_id text,
  destination_village_id text,
  started_at timestamptz not null default now()
);

-- Live bus state, readable by everyone. Driver name and route are copied in so
-- riders never need to read drivers or assignments.
create table public.bus_live (
  bus_id uuid primary key references public.buses on delete cascade,
  driver_id uuid not null unique references public.drivers on delete cascade,
  assignment_id uuid not null references public.village_assignments on delete cascade,
  driver_name text not null,
  bus_number int not null,
  village_id text not null references public.villages on delete cascade,
  destination_village_id text not null references public.villages on delete cascade,
  lat double precision,
  lng double precision,
  speed double precision,
  heading double precision,
  online boolean not null default true,
  is_full boolean not null default false,
  updated_at timestamptz not null default now(),
  last_sample_at timestamptz
);

-- Every ~30 s per bus, for reports only.
create table public.position_samples (
  id bigserial primary key,
  bus_id uuid,
  driver_id uuid,
  village_id text,
  lat double precision,
  lng double precision,
  at timestamptz not null default now()
);

-- ───────────────────────── riders waiting
create table public.waiting_requests (
  id uuid primary key default gen_random_uuid(),
  rider_uid uuid not null,
  village_id text not null references public.villages on delete cascade,
  destination_village_id text not null references public.villages on delete cascade,
  stop_id text not null references public.stops on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '15 minutes',
  status text not null default 'waiting' check (status in ('waiting', 'boarded', 'picked', 'expired', 'cancelled')),
  ended_at timestamptz
);
create unique index one_active_wait on public.waiting_requests (rider_uid) where status = 'waiting';
create index on public.waiting_requests (village_id, status);
create index on public.waiting_requests (created_at);

create table public.waiting_counts (
  village_id text not null references public.villages on delete cascade,
  destination_village_id text not null references public.villages on delete cascade,
  stop_id text not null references public.stops on delete cascade,
  n int not null default 0,
  primary key (village_id, destination_village_id, stop_id)
);

create table public.admins (
  uid uuid primary key references auth.users on delete cascade,
  created_at timestamptz not null default now()
);

-- ───────────────────────── helpers
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where uid = auth.uid());
$$;

create or replace function public.norm_phone(p text) returns text
language sql immutable as $$
  select regexp_replace(regexp_replace(regexp_replace(coalesce(p, ''), '\D', '', 'g'), '^252(?=\d{7,})', ''), '^0+', '');
$$;

create or replace function public.refresh_waiting_count(v text, d text, s text) returns void
language sql security definer set search_path = public as $$
  insert into public.waiting_counts (village_id, destination_village_id, stop_id, n)
  values (v, d, s, (select count(*) from public.waiting_requests w
                    where w.village_id = v and w.destination_village_id = d and w.stop_id = s
                      and w.status = 'waiting' and w.expires_at > now()))
  on conflict (village_id, destination_village_id, stop_id) do update set n = excluded.n
  where waiting_counts.n is distinct from excluded.n;
$$;

create or replace function public.waiting_requests_changed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.refresh_waiting_count(new.village_id, new.destination_village_id, new.stop_id);
  end if;
  if tg_op in ('UPDATE', 'DELETE') then
    if tg_op = 'DELETE' or (old.village_id, old.destination_village_id, old.stop_id) is distinct from (new.village_id, new.destination_village_id, new.stop_id) then
      perform public.refresh_waiting_count(old.village_id, old.destination_village_id, old.stop_id);
    end if;
  end if;
  return null;
end $$;

create trigger waiting_requests_count after insert or update or delete on public.waiting_requests
for each row execute function public.waiting_requests_changed();

-- ───────────────────────── row level security
alter table public.cities enable row level security;
alter table public.districts enable row level security;
alter table public.villages enable row level security;
alter table public.stops enable row level security;
alter table public.buses enable row level security;
alter table public.drivers enable row level security;
alter table public.village_assignments enable row level security;
alter table public.trips enable row level security;
alter table public.bus_live enable row level security;
alter table public.position_samples enable row level security;
alter table public.waiting_requests enable row level security;
alter table public.waiting_counts enable row level security;
alter table public.admins enable row level security;

-- Public map data: anyone may read; only admins may change.
create policy "read" on public.cities for select using (true);
create policy "read" on public.districts for select using (true);
create policy "read" on public.villages for select using (true);
create policy "read" on public.stops for select using (true);
create policy "read" on public.buses for select using (true);
create policy "read" on public.bus_live for select using (true);
create policy "read" on public.waiting_counts for select using (true);

create policy "admin write" on public.cities for all using (public.is_admin()) with check (public.is_admin());
create policy "admin write" on public.districts for all using (public.is_admin()) with check (public.is_admin());
create policy "admin write" on public.villages for all using (public.is_admin()) with check (public.is_admin());
create policy "admin write" on public.stops for all using (public.is_admin()) with check (public.is_admin());
create policy "admin write" on public.buses for all using (public.is_admin()) with check (public.is_admin());

-- Private rows: the owner (driver / rider) or an admin. All changes go through
-- the functions below.
create policy "self or admin" on public.drivers for select using (auth_uid = auth.uid() or public.is_admin());
create policy "self or admin" on public.village_assignments for select
  using (public.is_admin() or driver_id in (select id from public.drivers where auth_uid = auth.uid()));
create policy "admin" on public.trips for select using (public.is_admin());
create policy "admin" on public.position_samples for select using (public.is_admin());
create policy "self or admin" on public.waiting_requests for select using (rider_uid = auth.uid() or public.is_admin());
create policy "self" on public.admins for select using (uid = auth.uid());

-- pin_hash never leaves the database, not even to admins: grant every other column.
revoke all on public.drivers from anon, authenticated;
grant select (id, name, phone, bus_id, approved, auth_uid, failed_attempts, locked_until, created_at) on public.drivers to authenticated;

-- ───────────────────────── realtime
alter publication supabase_realtime add table
  public.bus_live, public.waiting_counts, public.waiting_requests, public.village_assignments,
  public.cities, public.districts, public.villages, public.stops, public.buses;
alter table public.bus_live replica identity full;
alter table public.waiting_counts replica identity full;
