#!/usr/bin/env bash
# Production Flutter Web build. Requires SUPABASE_URL and SUPABASE_ANON_KEY.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/app"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

: "${SUPABASE_URL:?Set SUPABASE_URL in .env or environment}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY in .env or environment}"

if [[ "$SUPABASE_URL" == http://127.0.0.1:* || "$SUPABASE_URL" == http://localhost:* ]]; then
  echo "ERROR: SUPABASE_URL points to local Supabase ($SUPABASE_URL)."
  echo "Production builds must use your hosted project URL, e.g. https://YOUR_REF.supabase.co"
  exit 1
fi

LOCAL_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
if [[ "$SUPABASE_ANON_KEY" == "$LOCAL_ANON_KEY" ]]; then
  echo "ERROR: SUPABASE_ANON_KEY is the local Supabase demo key."
  echo "Use the anon public key from Supabase Dashboard → Project Settings → API for your hosted project."
  exit 1
fi

APP_URL="${APP_URL:-${PASSWORD_RESET_REDIRECT:-http://localhost:3000}}"

cd "$APP_DIR"
flutter pub get
flutter build web --release \
  --no-web-resources-cdn \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=PASSWORD_RESET_REDIRECT="$APP_URL"

echo ""
echo "Built: $APP_DIR/build/web"
echo "Deploy that folder to any static host (Vercel, Netlify, Cloudflare Pages, etc.)."
