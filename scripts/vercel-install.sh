#!/usr/bin/env bash
# Install Flutter for Vercel (or any CI) when the SDK is not on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${FLUTTER_SDK:-$ROOT/.flutter-sdk}"

if [[ ! -x "$SDK/bin/flutter" ]]; then
  rm -rf "$SDK"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$SDK"
fi

"$SDK/bin/flutter" config --no-analytics
"$SDK/bin/flutter" precache --web

# When Root Directory is `app`, pubspec is in cwd; otherwise use app/.
if [[ -f pubspec.yaml ]]; then
  "$SDK/bin/flutter" pub get
elif [[ -f "$ROOT/app/pubspec.yaml" ]]; then
  (cd "$ROOT/app" && "$SDK/bin/flutter" pub get)
else
  echo "Could not find pubspec.yaml" >&2
  exit 1
fi
