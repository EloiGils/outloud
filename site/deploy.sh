#!/bin/bash
# Deploys the outloud landing site to CapRover (captain-04) as app "outloud".
# Prereq: a valid caprover login. If the token expired, run:  caprover login
set -euo pipefail
cd "$(dirname "$0")"

APP="outloud"
MACHINE="captain-04"
BASE="https://captain.cap.eloibreton.com"
TOKEN=$(python3 -c "import json,glob; d=json.load(open('$HOME/.config/configstore/caprover.json')); print(next(m['authToken'] for m in d['CapMachines'] if 'eloibreton' in m['baseUrl']))")

# register the app (ignore error if it already exists)
curl -s -X POST "$BASE/api/v2/user/apps/appDefinitions/register" \
  -H "x-captain-auth: $TOKEN" -H "x-namespace: captain" \
  -H "Content-Type: application/json" -d "{\"appName\":\"$APP\",\"hasPersistentData\":false}" >/dev/null || true

# deploy the current folder (contains captain-definition + html)
caprover deploy -n "$MACHINE" -a "$APP" -b main 2>/dev/null || caprover deploy -n "$MACHINE" -a "$APP"

echo "Deployed. Enable HTTPS + a domain for '$APP' in the CapRover panel:"
echo "  $BASE  →  Apps → $APP → HTTP Settings"
