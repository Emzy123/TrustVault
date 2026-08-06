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

APP_URL="${APP_URL:-${PASSWORD_RESET_REDIRECT:-http://localhost:3000}}"

cd "$APP_DIR"
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=PASSWORD_RESET_REDIRECT="$APP_URL"

echo ""
echo "Built: $APP_DIR/build/web"
echo "Deploy that folder to any static host (Vercel, Netlify, Cloudflare Pages, etc.)."
