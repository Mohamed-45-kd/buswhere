"""End-to-end check of the BusWhere backend on LOCAL Supabase (supabase start), through the public API.
Run: python supabase/tests/e2e.py <PUBLISHABLE_KEY> <SECRET_KEY>   (keys from `supabase status`). Needs a fresh `supabase db reset`."""
import json, subprocess, sys, urllib.request, urllib.error

API = 'http://127.0.0.1:54321'
KEY = sys.argv[1]
SECRET = sys.argv[2]
ok = fail = 0


def call(method, path, token=None, body=None, key=KEY):
    h = {'apikey': key, 'Content-Type': 'application/json', 'Authorization': f'Bearer {token or key}'}
    req = urllib.request.Request(API + path, method=method, headers=h, data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            t = r.read().decode()
            return r.status, (json.loads(t) if t else None)
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        try:
            return e.code, json.loads(t)
        except Exception:
            return e.code, t


def anon():
    s, j = call('POST', '/auth/v1/signup', body={})
    assert s == 200, (s, j)
    return j['access_token'], j['user']['id']


def rpc(tok, fn, **params):
    return call('POST', f'/rest/v1/rpc/{fn}', tok, params)


def check(name, cond, detail=''):
    global ok, fail
    if cond:
        ok += 1
        print('  PASS', name)
    else:
        fail += 1
        print('  FAIL', name, detail)


def sql(q):
    return subprocess.run(['docker', 'exec', 'supabase_db_buswhere', 'psql', '-U', 'postgres', '-tAc', q], capture_output=True, text=True).stdout.strip()


print('rider + driver sessions')
rider, rider_uid = anon()
rider2, _ = anon()
driver, _ = anon()
attacker, _ = anon()

s, j = call('GET', '/rest/v1/villages?select=id', rider)
check('riders can read villages', s == 200 and len(j) == 6, j)

print('driver sign-in')
s, j = rpc(driver, 'driver_sign_in', p_phone='+252 63 410 0012', p_pin='1234')
check('right PIN signs in (phone with +252 and spaces)', s == 200 and 'id' in j, j)
s, j = rpc(driver, 'driver_me')
check('driver_me returns Cali on bus 12', s == 200 and j['name'] == 'Cali' and j['bus']['number'] == 12, j)
check('driver_me does not expose pin_hash', 'pin_hash' not in json.dumps(j))

for i in range(5):
    s, j = rpc(attacker, 'driver_sign_in', p_phone='634100004', p_pin='0000')
check('5 wrong PINs: still bad-login', j.get('error') == 'bad-login', j)
s, j = rpc(attacker, 'driver_sign_in', p_phone='634100004', p_pin='1234')
check('then even the right PIN is locked', j.get('error') == 'locked', j)

print('assign, GPS, one village at a time')
s, j = rpc(driver, 'driver_assign', p_village='jigjigayar', p_destination='masalaha')
check('driver joins Jigjiga Yar -> Masalaha', s == 200, j)
s, j = rpc(driver, 'driver_assign', p_village='masalaha', p_destination='jigjigayar')
check('second active village refused', s >= 400 and 'already-active' in json.dumps(j), j)
s, j = rpc(driver, 'driver_ping', p_lat=9.5480, p_lng=44.0700, p_speed=6.0)
check('GPS ping accepted', s in (200, 204), j)
s, j = call('GET', '/rest/v1/bus_live?select=bus_number,driver_name,lat,village_id,destination_village_id', rider)
check('rider sees bus 12 at its GPS position', s == 200 and any(b['bus_number'] == 12 and b['lat'] == 9.548 for b in j), j)
s, j = rpc(attacker, 'driver_ping', p_lat=1, p_lng=1)
check('non-driver cannot send GPS', s >= 400, j)
check('report sample saved', sql("select count(*) from position_samples") == '1')

print('rider waiting')
s, j = rpc(rider, 'start_waiting', p_village='jigjigayar', p_destination='masalaha', p_stop='jj1')
check('rider taps "Waan sugayaa"', s == 200 and j['status'] == 'waiting', j)
s, j = rpc(rider, 'start_waiting', p_village='jigjigayar', p_destination='masalaha', p_stop='jj2')
s2, c = call('GET', '/rest/v1/waiting_counts?select=stop_id,n&n=gt.0', rider)
check('only one active wait per device (moved to jj2)', c == [{'stop_id': 'jj2', 'n': 1}], c)
rpc(rider2, 'start_waiting', p_village='jigjigayar', p_destination='masalaha', p_stop='jj2')
s, c = call('GET', '/rest/v1/waiting_counts?select=n&stop_id=eq.jj2', driver)
check('driver sees 2 waiting at jj2', c and c[0]['n'] == 2, c)
s, j = call('GET', '/rest/v1/waiting_requests?select=id', rider2)
check('a rider sees only their own request', s == 200 and len(j) == 1, j)
s, j = rpc(rider, 'start_waiting', p_village='jigjigayar', p_destination='masalaha', p_stop='ms1')
check('stop from another village refused', s >= 400 and 'bad-stop' in json.dumps(j), j)

print('private data')
s, j = call('GET', '/rest/v1/drivers?select=id,name,phone', rider)
check('riders cannot read drivers', s == 200 and j == [], j)
s, j = call('GET', '/rest/v1/drivers?select=pin_hash', driver)
check('nobody can read pin_hash', s >= 400, j)
s, j = call('PATCH', '/rest/v1/villages?id=eq.masalaha', rider, {'name_so': 'hacked'})
check('riders cannot edit villages', sql("select name_so from villages where id='masalaha'") == 'Masalaha', j)
s, j = call('PATCH', '/rest/v1/bus_live?bus_number=eq.12', attacker, {'lat': 0})
check('nobody can move a bus directly', sql("select lat from bus_live where bus_number=12") == '9.548', j)
s, j = rpc(rider, 'housekeeping')
check('housekeeping is not callable from the app', s >= 400, j)

print('pick-up, trip, withdraw')
s, j = rpc(driver, 'driver_pick_up', p_stop='jj2')
check('driver picks up 2 at jj2', j == 2, j)
s, c = call('GET', '/rest/v1/waiting_counts?select=n&stop_id=eq.jj2', rider)
check('count back to 0', c and c[0]['n'] == 0, c)
s, j = rpc(driver, 'driver_change_destination', p_destination='daloodo')
s, j = rpc(driver, 'driver_me')
check('new trip: destination Daloodo, same village', j['assignment']['destination_village_id'] == 'daloodo' and j['assignment']['village_id'] == 'jigjigayar', j)
s, j = rpc(driver, 'driver_set_status', p_full=True)
s, j = call('GET', '/rest/v1/bus_live?select=is_full&bus_number=eq.12', rider)
check('"bus full" visible to riders', j and j[0]['is_full'] is True, j)

print('housekeeping job')
rpc(rider2, 'start_waiting', p_village='jigjigayar', p_destination='masalaha', p_stop='jj3')
sql("update waiting_requests set expires_at = now() - interval '1 second' where stop_id='jj3'")
sql("update bus_live set updated_at = now() - interval '31 minutes' where bus_number=12")
sql("select public.housekeeping()")
check('wait expires after 15 min', sql("select status from waiting_requests where stop_id='jj3'") == 'expired')
check('jj3 count back to 0', sql("select n from waiting_counts where stop_id='jj3'") == '0')
check('driver silent 30 min is withdrawn', sql("select count(*) from bus_live") == '0' and sql("select end_reason from village_assignments order by started_at desc limit 1") == 'auto-offline')
check('pg_cron job scheduled every minute', sql("select schedule from cron.job where jobname='buswhere-housekeeping'") == '* * * * *')

print('admin')
s, j = call('POST', '/auth/v1/admin/users', SECRET, {'email': 'admin@buswhere.test', 'password': 'pilot-admin-pass', 'email_confirm': True}, key=SECRET)
check('create admin auth user (dashboard step)', s in (200, 201), j)
sql("insert into public.admins (uid) select id from auth.users where email='admin@buswhere.test' on conflict do nothing")
s, j = call('POST', '/auth/v1/token?grant_type=password', body={'email': 'admin@buswhere.test', 'password': 'pilot-admin-pass'})
admin = j['access_token']
s, j = rpc(admin, 'admin_save_driver', p_id=None, p_name='Saciid', p_phone='0634100024', p_pin='4321', p_bus=None, p_approved=True)
check('admin adds a driver', s == 200, j)
s, j = rpc(attacker, 'admin_save_driver', p_id=None, p_name='X', p_phone='634999999', p_pin='1111', p_bus=None, p_approved=True)
check('non-admin cannot add drivers', s >= 400 and 'not-admin' in json.dumps(j), j)
s, j = rpc(attacker, 'driver_sign_in', p_phone='634100024', p_pin='4321')
check('driver without a bus is told no-bus', j.get('error') == 'no-bus', j)
s, j = call('GET', '/rest/v1/drivers?select=name,phone', admin)
check('admin lists drivers (4)', s == 200 and len(j) == 4, j)
s, j = rpc(admin, 'admin_report')
check('admin report: trips and waits today', s == 200 and j['trips_today'] == 2 and j['waits_today'] >= 4, j)
s, j = rpc(rider, 'admin_report')
check('riders cannot read reports', s >= 400, j)
s, j = call('POST', '/rest/v1/stops', admin, {'village_id': 'daloodo', 'name': 'Masjidka Daloodo', 'lat': 9.548, 'lng': 44.07})
check('admin adds a stop', s == 201, j)

print(f'\n{ok} passed, {fail} failed')
sys.exit(1 if fail else 0)
