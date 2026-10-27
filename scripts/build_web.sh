#!/usr/bin/env bash
# Build the BusWhere PWA for a Supabase project.
#   SUPABASE_URL=https://xxxx.supabase.co SUPABASE_ANON_KEY=... scripts/build_web.sh
# Output: buswhere_app/build/web (deploy that folder).
set -euo pipefail
: "${SUPABASE_URL:?set SUPABASE_URL}"
: "${SUPABASE_ANON_KEY:?set SUPABASE_ANON_KEY}"
cd "$(dirname "$0")/../buswhere_app"
flutter build web --release --no-wasm-dry-run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
# New cache name per build so phones pick up the update on their next open.
sed -i "s/const VERSION = 'bw-v[^']*';/const VERSION = 'bw-$(date +%Y%m%d%H%M%S)';/" build/web/sw.js
echo "Built buswhere_app/build/web for $SUPABASE_URL"
