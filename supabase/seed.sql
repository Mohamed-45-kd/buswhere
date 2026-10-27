-- LOCAL TESTING ONLY (supabase db reset). Not applied to the hosted project.
-- Test drivers all use PIN 1234 (Cali 634100012, Maxamed 634100004, Cabdi 634100009).
-- Local test admin: supabase/tests/make_local_admin.sh
insert into public.buses (number, plate, capacity, owner) values
  (4, 'HR 4828', 14, 'Shirkadda Hiigsi'), (9, 'HR 4863', 11, 'Mulkiile gaar ah'), (12, 'HR 4884', 14, 'Shirkadda Hiigsi');

insert into public.drivers (name, phone, pin_hash, bus_id)
select x.name, x.phone, extensions.crypt('1234', extensions.gen_salt('bf')), b.id
from (values ('Cali', '634100012', 12), ('Maxamed', '634100004', 4), ('Cabdi', '634100009', 9)) x(name, phone, bus)
join public.buses b on b.number = x.bus;
