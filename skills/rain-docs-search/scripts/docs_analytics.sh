#!/usr/bin/env bash
# Export Rain docs usage analytics via the Mintlify Analytics API.
#
#   GET https://api.mintlify.com/v1/analytics/{projectId}/<report>
#   Authorization: Bearer $MINTLIFY_ADMIN_KEY   (admin key, mint_ prefix)
#
# Usage:
#   MINTLIFY_ADMIN_KEY=... MINTLIFY_PROJECT_ID=... docs_analytics.sh REPORT [key=value ...]
#
# REPORT is the endpoint path segment. Known reports (see the skill's
# references/mintlify-api.md for verification status):
#   visitors  page-views  search-queries  feedback  feedback-by-page
#   assistant-conversations  caller-stats
#
# Trailing key=value pairs become URL query parameters, e.g.:
#   docs_analytics.sh search-queries dateFrom=2026-01-01 dateTo=2026-07-21
#   docs_analytics.sh visitors limit=100 offset=0
#
# Pagination: responses use limit/offset with a hasMore flag — keep requesting
# with offset += limit while hasMore is true before totalling anything.
#
# Environment:
#   MINTLIFY_ADMIN_KEY   required — admin API key (mint_...), org-wide secret.
#   MINTLIFY_PROJECT_ID  required — the project id for the docs deployment.
#
# Output: the response body (pretty-printed JSON when python3 is available),
# then a final line `HTTP <status>`.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  sed -n '2,27p' "$0" >&2
  exit 2
fi

REPORT="$1"
shift

: "${MINTLIFY_ADMIN_KEY:?set MINTLIFY_ADMIN_KEY (mint_... admin key from the Mintlify dashboard)}"
: "${MINTLIFY_PROJECT_ID:?set MINTLIFY_PROJECT_ID (project id for the docs deployment)}"

QS=""
for kv in "$@"; do
  ENC="$(python3 - "$kv" <<'PY'
import sys, urllib.parse
k, _, v = sys.argv[1].partition("=")
print(f"{urllib.parse.quote(k, safe='')}={urllib.parse.quote(v, safe='')}")
PY
)"
  QS="${QS:+${QS}&}${ENC}"
done

URL="https://api.mintlify.com/v1/analytics/${MINTLIFY_PROJECT_ID}/${REPORT}${QS:+?${QS}}"

RESP_FILE="$(mktemp)"
trap 'rm -f "$RESP_FILE"' EXIT

STATUS="$(curl -sS -o "$RESP_FILE" -w '%{http_code}' \
  -X GET "$URL" \
  -H "Authorization: Bearer ${MINTLIFY_ADMIN_KEY}")"

python3 -m json.tool "$RESP_FILE" 2>/dev/null || cat "$RESP_FILE"
echo "HTTP ${STATUS}"

if [[ "$STATUS" == "404" ]]; then
  echo "note: 404 — the '${REPORT}' path segment may differ from this guess." >&2
  echo "Check the live endpoint list at https://mintlify.com/docs/api/introduction" >&2
  echo "(Analytics section) and pass the exact segment. Do not brute-force variants." >&2
fi
