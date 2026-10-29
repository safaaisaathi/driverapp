#!/usr/bin/env bash
# One-command real-project run (see GLOSSARY.md "Live-device runbook").
#
#   ./scripts/run_device.sh RZ8NA1CAS3T     # specific device
#   ./scripts/run_device.sh                 # let flutter pick the device
#
# Keys come from the gitignored `.env` (PRD-2 §0.10: ".env and
# google-services.json are shared privately"), compiled in with
# `--dart-define-from-file`. The Dart code reads them via
# String.fromEnvironment, so the delivery method is invisible to the app.
#
# No `.env` yet? This script regenerates one from the flutterfire-generated
# `lib/firebase_options.dart`. On a fresh clone (neither file exists) run
# `flutterfire configure` first.
#
# Emulator-mode runs stay manual — a key defined in a defines-file cannot
# also be passed via --dart-define, so the switch is its own command:
#   flutter run --dart-define=DRIVERAPP_USE_EMULATOR=true \
#     --dart-define=DRIVERAPP_EMULATOR_HOST=<dev-machine LAN IP>
set -euo pipefail

cd "$(dirname "$0")/.."

env_file='.env'

# Bootstrap the private .env from the flutterfire-generated file if absent.
if [[ ! -f $env_file ]]; then
  gen='lib/firebase_options.dart'
  if [[ ! -f $gen ]]; then
    echo "error: no $env_file and no $gen — run 'flutterfire configure' once, then retry." >&2
    exit 1
  fi
  {
    echo '# Auto-generated from lib/firebase_options.dart — PRIVATE (PRD-2 §0.10), gitignored.'
    echo 'DRIVERAPP_USE_EMULATOR=false'
    grep -oP "apiKey: '\K[^']+" "$gen" | head -1 | sed 's/^/DRIVERAPP_FB_API_KEY=/'
    grep -oP "appId: '\K[^']+" "$gen" | head -1 | sed 's/^/DRIVERAPP_FB_APP_ID=/'
    grep -oP "messagingSenderId: '\K[^']+" "$gen" | head -1 | sed 's/^/DRIVERAPP_FB_SENDER_ID=/'
  } > "$env_file"
  echo "created $env_file from $gen"
fi

# First arg (optional) = device id, forwarded with -d. No arg = flutter picks.
device_args=()
if [[ $# -gt 0 ]]; then
  device_args=(-d "$1")
fi

exec flutter run --dart-define-from-file="$env_file" "${device_args[@]}"
