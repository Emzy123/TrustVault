#!/usr/bin/env bash
# Build Flutter Web for Vercel.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${FLUTTER_SDK:-$ROOT/.flutter-sdk}"

if [[ -f pubspec.yaml ]]; then
  APP_DIR="$(pwd)"
elif [[ -f "$ROOT/app/pubspec.yaml" ]]; then
  APP_DIR="$ROOT/app"
  SDK="${FLUTTER_SDK:-$ROOT/.flutter-sdk}"
else
  echo "Could not find Flutter app" >&2
  exit 1
fi

# Prefer SDK next to the app when Root Directory is `app`.
if [[ ! -x "$SDK/bin/flutter" && -x "$APP_DIR/.flutter-sdk/bin/flutter" ]]; then
  SDK="$APP_DIR/.flutter-sdk"
fi

if [[ ! -x "$SDK/bin/flutter" ]]; then
  echo "Flutter SDK missing at $SDK — run scripts/vercel-install.sh first" >&2
  exit 1
fi

REDIRECT="${APP_URL:-https://${VERCEL_URL:-localhost}}"

cd "$APP_DIR"
"$SDK/bin/flutter" build web --release --no-web-resources-cdn \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=PASSWORD_RESET_REDIRECT="$REDIRECT"
