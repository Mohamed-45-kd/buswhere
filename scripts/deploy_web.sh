#!/usr/bin/env bash
# Build the PWA for the live Supabase project and deploy it to Vercel (buswhere-five.vercel.app).
#   scripts/deploy_web.sh
# Reads SUPABASE_URL and SUPABASE_ANON_KEY (the publishable key) from .env.pilot.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env.pilot; set +a
bash scripts/build_web.sh
# flutter build wipes build/web, so restore the Vercel project link before deploying.
cp -r .vercel-buswhere buswhere_app/build/web/.vercel
cd buswhere_app/build/web
vercel deploy --prod --yes
