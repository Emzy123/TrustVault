#!/usr/bin/env bash
# Link hosted Supabase, push migrations, deploy send-email, set secrets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT_REF="${SUPABASE_PROJECT_REF:-xrumgoeuzufxidxwwusm}"

if ! npx supabase projects list >/dev/null 2>&1; then
  echo "Not logged in. Run: npx supabase login"
  exit 1
fi

echo "Linking project $PROJECT_REF..."
npx supabase link --project-ref "$PROJECT_REF"

echo "Pushing migrations..."
npx supabase db push

echo ""
echo "Deploying edge function send-email..."
npx supabase functions deploy send-email --no-verify-jwt

if [[ -n "${BREVO_API_KEY:-}" ]]; then
  npx supabase secrets set \
    BREVO_API_KEY="$BREVO_API_KEY" \
    BREVO_SENDER_EMAIL="${BREVO_SENDER_EMAIL:?Set BREVO_SENDER_EMAIL}" \
    BREVO_SENDER_NAME="${BREVO_SENDER_NAME:-Atlas}" \
    APP_URL="${APP_URL:?Set APP_URL to your public web app URL}"
else
  echo ""
  echo "Skip secrets: set BREVO_API_KEY, BREVO_SENDER_EMAIL, APP_URL in .env then re-run,"
  echo "  or: npx supabase secrets set BREVO_API_KEY=... BREVO_SENDER_EMAIL=... APP_URL=..."
fi

echo ""
echo "Next: In Supabase Dashboard → SQL Editor, run (once):"
echo "  1. supabase/seed_auth.sql"
echo "  2. supabase/seed.sql"
echo ""
echo "Auth → URL configuration:"
echo "  Site URL = your APP_URL"
echo "  Redirect URLs = APP_URL, APP_URL/**"
echo ""
echo "Optional: Auth → SMTP (Brevo) for password-reset emails — see supabase/EMAIL.md"
