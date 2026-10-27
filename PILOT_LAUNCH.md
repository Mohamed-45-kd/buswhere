# BusWhere — pilot launch (26 Juun, Hargeisa)

The app is a Flutter PWA (`buswhere_app/`) on a Supabase backend (`supabase/`).
Riders need no account. Drivers sign in with phone + a PIN the admin gives them.
Admins sign in with email + password.

You do steps 1–4 and 6 yourself: they use your accounts. Everything else is in the repo.

## 1. Create the Supabase project
1. On supabase.com, create a project named `buswhere`. Pick the region nearest Hargeisa that is offered (e.g. Frankfurt).
   Save the database password in your password manager.
2. **Authentication → Sign In / Providers**
   - Turn **Allow anonymous sign-ins** on (riders use these).
   - Leave **Email** enabled: admins sign in with it. Anyone who signs up by email gets no more
     access than a rider; only accounts listed in the `admins` table can manage BusWhere.
3. **Authentication → Rate Limits**: raise *anonymous sign-ins per hour* to about 1000.
   Many riders share one mobile-network IP address.
4. **Project Settings → API**: copy the **Project URL** and the **anon / publishable key**.
   (Both are safe to put in the app. Never put the `service_role` key in the app.)

## 2. Load the database
In a terminal in this folder (`C:\Users\Admin\Desktop\Buswhere`):

```bash
supabase login
```

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

```bash
supabase db push
```

This creates the tables, rules, functions, the every-minute housekeeping job
(15-minute wait expiry, auto-withdraw after 30 minutes offline) and the
placeholder 26 Juun villages and stops. `supabase/seed.sql` (test drivers) is **not** pushed.

## 3. Make yourself an admin
1. **Authentication → Users → Add user → Create new user**: your email and a strong password, tick *Auto confirm*.
2. **SQL Editor**, run (with your email):

```sql
insert into public.admins (uid) select id from auth.users where email = 'you@example.com';
```

## 4. Build and deploy the app
Live project: `tvdoraoiuupdipsbehph` · live site: **https://buswhere-five.vercel.app** (Vercel project `buswhere`).

`.env.pilot` holds the project URL and the publishable key (both safe in the app; never the secret or
service_role key). `.vercel-buswhere/` holds the Vercel project link. Both are git-ignored.

To publish a new version after any change:

```bash
bash scripts/deploy_web.sh
```

In Supabase, **Authentication → URL Configuration → Site URL** should be `https://buswhere-five.vercel.app`.

## 5. Set up the pilot in the app
Open the address, tap **Maamul · Admin** and sign in.
- **Meelaha / Places**: open each village, fix its name, tap **Dhig tuulada** and tap where it is,
  then **Ku dar joogsi** and tap each real stop (market, mosque, school…). Turn off villages that are not in the pilot.
- **Darawal / Drivers**: register each bus (number, plate, seats), then add each driver
  (first name, phone, a 4-digit PIN, their bus). Give each driver their PIN in person.

## 6. Driver day-one checklist (about 8 drivers)
- Open the address in Chrome on the driver's Android phone → menu → **Install app / Add to Home screen**.
- Sign in with phone + PIN, allow **location** when asked.
- Pick the village and destination, tap **Ku biir oo bilow**. Check the bus shows on a rider phone.
- Keep the app open on screen while driving (the app keeps the screen awake) and keep the phone on a charger.
  A web app cannot send GPS from the background — this is the doc's "later: native driver app".
- At the end of a trip tap **Beddel** for the new destination; tap **Ka bax** to leave the village.

## Known limits for the pilot
- Map tiles come from openstreetmap.org (free, fair-use). Before opening to all riders, switch to a keyed
  provider (CARTO, MapTiler or Stadia; CARTO's free basemaps now require a key) in `lib/widgets/bus_map.dart`.
- ETAs are straight-line distance × 1.3 at the bus's GPS speed (≈18 km/h if unknown). No road routing.
- No village boundaries yet, so no "left the village for 10 minutes" auto-withdraw; only the 30-minute offline rule.
- Alerts ("bus is 2 minutes away") show while the rider has the app open; no push notifications when it's closed.
- Somali copy still needs a native-speaker review.

## Local development
`supabase start` runs the backend in Docker; `supabase db reset` reloads it with the test drivers in `supabase/seed.sql`
(PIN `1234`). Build the app against it with the local URL and the publishable key that `supabase status` prints.
