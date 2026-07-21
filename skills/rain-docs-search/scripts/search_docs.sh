#!/usr/bin/env bash
# Search the Rain docs via the Mintlify Search API.
#
#   POST https://api-dsc.mintlify.com/v1/search/{domain}
#   Authorization: Bearer $MINTLIFY_ASSISTANT_KEY   (assistant key, mint_dsc_ prefix)
#
# Usage:
#   MINTLIFY_ASSISTANT_KEY=... MINTLIFY_DOMAIN=... search_docs.sh QUERY [PAGE_SIZE]
#
# Examples:
#   search_docs.sh "partner managed settlement"
#   search_docs.sh "decrypt card secrets" 5
#
# Environment:
#   MINTLIFY_ASSISTANT_KEY  required — assistant API key (mint_dsc_...), from the
#                           Mintlify dashboard API-keys page.
#   MINTLIFY_DOMAIN         required — the docs subdomain slug from the dashboard
#                           URL (dashboard.mintlify.com/<org>/<subdomain>), NOT
#                           the custom domain docs.rain.xyz.
#   MINTLIFY_VERSION        optional — filter results to a docs version.
#   MINTLIFY_LANGUAGE       optional — filter results to a language.
#
# Output: the response body (pretty-printed JSON when python3 is available),
# then a final line `HTTP <status>`.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  sed -n '2,24p' "$0" >&2
  exit 2
fi

QUERY="$1"
PAGE_SIZE="${2:-10}"

: "${MINTLIFY_ASSISTANT_KEY:?set MINTLIFY_ASSISTANT_KEY (mint_dsc_... key from the Mintlify dashboard)}"
: "${MINTLIFY_DOMAIN:?set MINTLIFY_DOMAIN (docs subdomain slug from the Mintlify dashboard URL)}"

BODY="$(python3 - "$QUERY" "$PAGE_SIZE" <<'PY'
import json, os, sys
body = {"query": sys.argv[1], "pageSize": int(sys.argv[2])}
flt = {}
for env, key in (("MINTLIFY_VERSION", "version"), ("MINTLIFY_LANGUAGE", "language")):
    if os.environ.get(env):
        flt[key] = os.environ[env]
if flt:
    body["filter"] = flt
print(json.dumps(body))
PY
)"

RESP_FILE="$(mktemp)"
trap 'rm -f "$RESP_FILE"' EXIT

STATUS="$(curl -sS -o "$RESP_FILE" -w '%{http_code}' \
  -X POST "https://api-dsc.mintlify.com/v1/search/${MINTLIFY_DOMAIN}" \
  -H "Authorization: Bearer ${MINTLIFY_ASSISTANT_KEY}" \
  -H "Content-Type: application/json" \
  --data "$BODY")"

python3 -m json.tool "$RESP_FILE" 2>/dev/null || cat "$RESP_FILE"
echo "HTTP ${STATUS}"
