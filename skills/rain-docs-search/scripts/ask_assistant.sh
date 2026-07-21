#!/usr/bin/env bash
# Ask the Rain docs AI assistant a question via the Mintlify Assistant API.
#
#   POST https://api-dsc.mintlify.com/v1/assistant/{domain}/message
#   Authorization: Bearer $MINTLIFY_ASSISTANT_KEY   (assistant key, mint_dsc_ prefix)
#
# The response is a text STREAM interleaving the generated answer with the
# retrieved documentation chunks; this script prints it as it arrives.
#
# Usage:
#   MINTLIFY_ASSISTANT_KEY=... MINTLIFY_DOMAIN=... ask_assistant.sh QUESTION
#
# Example:
#   ask_assistant.sh "How do I activate a physical card?"
#
# Environment:
#   MINTLIFY_ASSISTANT_KEY   required — assistant API key (mint_dsc_...).
#   MINTLIFY_DOMAIN          required — docs subdomain slug (see search_docs.sh).
#   MINTLIFY_RETRIEVAL_SIZE  optional — number of doc chunks to retrieve.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  sed -n '2,20p' "$0" >&2
  exit 2
fi

QUESTION="$1"

: "${MINTLIFY_ASSISTANT_KEY:?set MINTLIFY_ASSISTANT_KEY (mint_dsc_... key from the Mintlify dashboard)}"
: "${MINTLIFY_DOMAIN:?set MINTLIFY_DOMAIN (docs subdomain slug from the Mintlify dashboard URL)}"

BODY="$(python3 - "$QUESTION" <<'PY'
import json, os, sys
q = sys.argv[1]
body = {
    # fp is a caller identifier ("fingerprint"); an arbitrary stable string is fine
    # and keeps agent traffic distinguishable in the assistant analytics.
    "fp": "rain-agent-skills",
    "messages": [
        {
            "id": "msg-1",
            "role": "user",
            "content": q,
            "parts": [{"type": "text", "text": q}],
        }
    ],
}
if os.environ.get("MINTLIFY_RETRIEVAL_SIZE"):
    body["retrievalPageSize"] = int(os.environ["MINTLIFY_RETRIEVAL_SIZE"])
print(json.dumps(body))
PY
)"

# -N disables buffering so the stream renders incrementally.
curl -sS -N \
  -X POST "https://api-dsc.mintlify.com/v1/assistant/${MINTLIFY_DOMAIN}/message" \
  -H "Authorization: Bearer ${MINTLIFY_ASSISTANT_KEY}" \
  -H "Content-Type: application/json" \
  --data "$BODY"
echo
