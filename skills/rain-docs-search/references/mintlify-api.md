# Mintlify API reference (for Rain docs)

Everything this skill calls, in one place. Source of truth: the live Mintlify
API reference at `https://mintlify.com/docs/api/introduction`. Each endpoint
below is marked **verified** (spec confirmed against the Mintlify docs when
this skill was written, July 2026) or **verify before use** (documented to
exist, exact path/fields not independently confirmed — check the live
reference first; never guess variants).

## API keys

Generate keys on the **API keys** page of the Mintlify dashboard
(`https://dashboard.mintlify.com`). Keys belong to the **organization**, not a
single deployment, so one leaked key exposes every docs project in the org.
Keep them in environment variables or a secrets manager only.

| Key type | Prefix | Grants |
| --- | --- | --- |
| Assistant API key | `mint_dsc_` | Search documentation, Assistant messages |
| Admin API key | `mint_` | Analytics export, trigger update, deployment status |

Identifiers you also need:

- **`{domain}`** — the docs subdomain slug. Read it from the dashboard URL:
  `https://dashboard.mintlify.com/<org>/<subdomain>` → `<subdomain>`. The
  default hosted site lives at `<subdomain>.mintlify.app`. Do **not** use the
  custom domain (`docs.rain.xyz`) here.
- **`{projectId}`** — the docs project id, used by Analytics endpoints. Find
  it in the dashboard project settings.

## Search documentation — verified

```
POST https://api-dsc.mintlify.com/v1/search/{domain}
Authorization: Bearer <assistant key>
Content-Type: application/json
```

Request body:

```json
{
  "query": "partner managed settlement",
  "pageSize": 10,
  "filter": {
    "version": "<optional docs version>",
    "language": "<optional language>"
  }
}
```

- `query` (string, required) — keyword-style queries work best.
- `pageSize` (number, optional, default 10) — max results.
- `filter` (object, optional) — omit entirely when unused.

Response: a JSON **array** of result objects carrying the matched page
content, the page path, and metadata (title/section). Results are page
*chunks* — de-duplicate by path when counting pages. Map a path to the live
site as `https://docs.rain.xyz/<path>`.

curl (what `scripts/search_docs.sh` runs):

```bash
curl -sS -X POST "https://api-dsc.mintlify.com/v1/search/${MINTLIFY_DOMAIN}" \
  -H "Authorization: Bearer ${MINTLIFY_ASSISTANT_KEY}" \
  -H "Content-Type: application/json" \
  --data '{"query":"partner managed settlement","pageSize":10}'
```

## Assistant message — verified (body fields), stream format may evolve

```
POST https://api-dsc.mintlify.com/v1/assistant/{domain}/message
Authorization: Bearer <assistant key>
Content-Type: application/json
```

Request body:

```json
{
  "fp": "rain-agent-skills",
  "messages": [
    {
      "id": "msg-1",
      "role": "user",
      "content": "How do I activate a physical card?",
      "parts": [{ "type": "text", "text": "How do I activate a physical card?" }]
    }
  ],
  "threadId": "<optional, to continue a conversation>",
  "retrievalPageSize": 10,
  "filter": {}
}
```

- `fp` — a caller identifier ("fingerprint"); any stable string. Using a
  distinctive value keeps agent traffic identifiable in assistant analytics.
- `messages` — the conversation history; append prior turns to continue one.

Response: a **text stream** interleaving the assistant's answer with the
retrieved documentation chunks (`scripts/ask_assistant.sh` prints it with
`curl -N`). The exact stream framing follows Mintlify's assistant protocol
and may change — treat it as human/agent-readable text, not a stable schema.

## Analytics export — admin key

Base pattern:

```
GET https://api.mintlify.com/v1/analytics/{projectId}/<report>
Authorization: Bearer <admin key>
```

Common query parameters: `dateFrom`, `dateTo` (ISO dates), `limit`, `offset`.
Responses paginate offset-style with a `hasMore` flag — loop
`offset += limit` while `hasMore` is `true` before aggregating.

| Report | Path segment | Status |
| --- | --- | --- |
| Unique visitors | `visitors` | **verified** — includes site-wide totals and per-page breakdowns, split human vs AI traffic |
| Page views | `page-views` | verify before use |
| Search queries | `search-queries` | verify before use |
| User feedback | `feedback` | verify before use |
| Feedback by page | `feedback-by-page` | verify before use |
| Assistant conversations | `assistant-conversations` | verify before use |
| Assistant caller stats | `caller-stats` | verify before use |

All seven reports are documented Mintlify capabilities ("export feedback,
assistant conversations, search analytics, page views, and visitor data");
only the `visitors` path segment was confirmed verbatim. On a `404`, read the
exact segment off the live reference under
`https://mintlify.com/docs/api/introduction` → Analytics, then retry once with
the corrected path.

## Adjacent endpoints (admin key) — not wrapped by this skill

- **Trigger update** / **Get deployment status** — redeploy the docs and poll
  the build. Documented under the same API reference. Out of scope here; if
  the user wants to ship docs changes, that's a `rain-platform-docs` workflow,
  not a search task.

## Zero-key access paths

Mintlify also exposes docs content without any API key:

- **`.md` suffix** — every page serves raw Markdown at `<page-url>.md`.
- **`/llms.txt`** and **`/llms-full.txt`** — machine-readable site indexes.

⚠️ Rain's docs site is **login-gated**, so unauthenticated fetches of these
may redirect to a login page. A local checkout of `rain-platform-docs` (the
`.mdx` sources plus `docs.json` navigation) is the reliable offline
equivalent.
