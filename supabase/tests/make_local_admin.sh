#!/usr/bin/env bash
# LOCAL ONLY: create a test admin on `supabase start` (never run against the hosted project).
# Sign in to the app's admin area with admin@buswhere.test / pilot-admin-pass
set -euo pipefail
SECRET=$(supabase status -o json | python -c "import json,sys; print(json.load(sys.stdin)['SECRET_KEY'])")
curl -s -X POST http://127.0.0.1:54321/auth/v1/admin/users -H "apikey: $SECRET" -H "Authorization: Bearer $SECRET" \
  -H "Content-Type: application/json" -d '{"email":"admin@buswhere.test","password":"pilot-admin-pass","email_confirm":true}' >/dev/null
docker exec supabase_db_buswhere psql -U postgres -tAc \
  "insert into public.admins (uid) select id from auth.users where email='admin@buswhere.test' on conflict do nothing"
echo "Local admin ready."
