# BusWhere — Ogow halka uu basku joogo

Live city-bus tracking for Hargeisa (pilot: 26 Juun district). Riders see buses heading to their
village with ETAs and tap **Waan sugayaa**; drivers see how many people wait at each stop.

- `buswhere_app/` — Flutter app, built as an installable PWA (rider, driver, admin)
- `supabase/` — database schema, security rules, functions and tests (Supabase: Postgres + Realtime)
- `scripts/` — `build_web.sh`, `deploy_web.sh` (Vercel)
- `PILOT_LAUNCH.md` — how the pilot is set up and run

Live: https://buswhere-five.vercel.app
