-- Placeholder places for the 26 Juun pilot, from the design-system UI kits.
-- Names and positions must be confirmed; admins edit them in the app.
insert into public.cities (id, name_so, name_en, is_active, sort) values
  ('hargeysa', 'Hargeysa', 'Hargeisa', true, 0),
  ('burco', 'Burco', 'Burao', false, 1);

insert into public.districts (id, city_id, name, is_active, sort) values
  ('26juun', 'hargeysa', '26 Juun', true, 0),
  ('axmed', 'hargeysa', 'Axmed Dhagax', false, 1),
  ('gacan', 'hargeysa', 'Gacan Libaax', false, 2),
  ('koodbuur', 'hargeysa', 'Koodbuur', false, 3);

insert into public.villages (id, district_id, name_so, name_en, lat, lng) values
  ('jigjigayar', '26juun', 'Jigjiga Yar', 'Jigjiga Yar', 9.5590, 44.0915),
  ('masalaha', '26juun', 'Masalaha', 'Masalaha', 9.5675, 44.1050),
  ('calaamadaha', '26juun', 'Calaamadaha', 'Calaamadaha', 9.5515, 44.0775),
  ('daloodo', '26juun', 'Daloodo', 'Daloodo', 9.5470, 44.0690),
  ('xeroawr', '26juun', 'Xero Awr', 'Xero Awr', 9.5430, 44.0960),
  ('baddacas', '26juun', 'Badda Cas', 'Badda Cas', 9.5660, 44.0820);

insert into public.stops (id, village_id, name, sub, lat, lng, sort) values
  ('jj1', 'jigjigayar', 'Isgoyska weyn', 'Main junction', 9.5572, 44.0890, 0),
  ('jj2', 'jigjigayar', 'Dugsiga', 'School', 9.5585, 44.0908, 1),
  ('jj3', 'jigjigayar', 'Masjidka', 'Mosque', 9.5597, 44.0926, 2),
  ('jj4', 'jigjigayar', 'Suuqa yar', 'Small market', 9.5610, 44.0944, 3),
  ('ms1', 'masalaha', 'Wadada weyn', 'Main road', 9.5660, 44.1028, 0),
  ('ms2', 'masalaha', 'Isbitaalka', 'Hospital', 9.5684, 44.1062, 1),
  ('ca1', 'calaamadaha', 'Calaamadaha 1', null, 9.5508, 44.0762, 0),
  ('ca2', 'calaamadaha', 'Calaamadaha 2', null, 9.5523, 44.0790, 1),
  ('dl1', 'daloodo', 'Suuqa Daloodo', 'Market', 9.5472, 44.0695, 0),
  ('xa1', 'xeroawr', 'Xero Awr', 'Centre', 9.5432, 44.0955, 0),
  ('bc1', 'baddacas', 'Badda Cas', 'Centre', 9.5655, 44.0825, 0),
  ('bc2', 'baddacas', 'Xarunta caafimaadka', 'Health centre', 9.5668, 44.0840, 1);
