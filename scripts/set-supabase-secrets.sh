#!/usr/bin/env bash
# Push Brevo + APP_URL secrets to hosted Supabase (edge function `send-email`).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

PROJECT_REF="${SUPABASE_PROJECT_REF:-xrumgoeuzufxidxwwusm}"

: "${BREVO_API_KEY:?Set BREVO_API_KEY in .env}"
: "${BREVO_SENDER_EMAIL:?Set BREVO_SENDER_EMAIL in .env}"
: "${APP_URL:?Set APP_URL in .env}"

if ! npx supabase projects list >/dev/null 2>&1; then
  echo "Not logged in. Run: npx supabase login"
  exit 1
fi

echo "Setting secrets on project $PROJECT_REF..."
npx supabase secrets set --project-ref "$PROJECT_REF" \
  BREVO_API_KEY="$BREVO_API_KEY" \
  BREVO_SENDER_EMAIL="$BREVO_SENDER_EMAIL" \
  BREVO_SENDER_NAME="${BREVO_SENDER_NAME:-TrustVault}" \
  APP_URL="$APP_URL"

echo "Done. Verify in Dashboard → Project Settings → Edge Functions → Secrets."
