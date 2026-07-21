---
name: rain-docs-search
description: Find the right Rain documentation page for any topic by querying the Mintlify Search API that hosts docs.rain.xyz, and pull docs usage analytics (searches, page views, unique visitors, assistant conversations, feedback) from the Mintlify Analytics export API. TRIGGER when the user asks "where is X documented", "find the docs page for/about Y", "what doc should I link", wants the canonical docs URL to cite in a support reply / PR / README / another skill, wants to search docs.rain.xyz programmatically, mentions the Mintlify search or assistant API, or asks for docs stats / engagement metrics / a Coinbase-style docs usage report. SKIP when the user wants to CALL the Rain Issuing API itself — authentication / SDK setup / webhooks → `rain-api-auth`; issuing a card + KYC + card secrets → `rain-issue-consumer-card`; spend webhooks + transaction lifecycle → `rain-managed-authorizations`; any other raincards.xyz endpoint → `rain-api-generic`. This skill finds and measures documentation; it never calls raincards.xyz.
allowed-tools: Read, Bash, Grep
---

# Rain — docs search & docs analytics (Mintlify API)

Rain's documentation (`https://docs.rain.xyz`) is hosted on **Mintlify**, which
exposes REST APIs for the docs themselves: a **Search API** to find the right
page for a topic, an **Assistant API** to get an answer grounded in the docs,
and an **Analytics export API** to pull usage stats (searches, page views,
visitors, assistant conversations, feedback). This skill wraps all three.

Use it to answer "which docs page covers X?" with a real, verified link — not a
guess — and to report how the docs are being used.

## When to invoke

- "Where do the Rain docs explain settlement for partner-managed programs?"
- "Find the right docs page to link in this support reply / PR description."
- "Search docs.rain.xyz for `spendingLimit` and give me the page."
- "Ask the docs assistant how card activation works and cite the source pages."
- "Pull our docs stats — top searches, page views, unique visitors this month."

If the ask is to *do* the thing (call an endpoint, verify a webhook, issue a
card) rather than to *find where it's documented*, hand off to the sibling
skill named in the description and only come back here for the citation link.

## Keys and environment

Two Mintlify key types exist, generated on the **API keys** page of the
Mintlify dashboard (`https://dashboard.mintlify.com`). Both are
**organization-wide secrets** — keep them in environment variables, never in
source or prompts (see the repo `SECURITY.md`):

| Variable | Key type | Prefix | Used by |
| --- | --- | --- | --- |
| `MINTLIFY_ASSISTANT_KEY` | Assistant API key | `mint_dsc_` | Search + Assistant endpoints |
| `MINTLIFY_ADMIN_KEY` | Admin API key | `mint_` | Analytics export (and update triggers) |
| `MINTLIFY_DOMAIN` | — | — | The docs **subdomain slug** for Search/Assistant |
| `MINTLIFY_PROJECT_ID` | — | — | The project id for Analytics |

`MINTLIFY_DOMAIN` is the subdomain identifier from the dashboard URL —
`https://dashboard.mintlify.com/<org>/<subdomain>` → use `<subdomain>`. It is
**not** `docs.rain.xyz`. If you don't have it, ask the user to read it off the
dashboard; do not guess.

If a required variable is missing, stop and ask the user for it — the scripts
refuse to run without their keys rather than sending unauthenticated requests.

## Procedure — find the right docs page

### 1. Search

```bash
${CLAUDE_SKILL_DIR}/scripts/search_docs.sh "partner managed settlement"
${CLAUDE_SKILL_DIR}/scripts/search_docs.sh "decrypt card secrets" 5
```

This calls `POST https://api-dsc.mintlify.com/v1/search/{domain}` with the
assistant key and prints the result JSON (an array of matches with page
content, path, and metadata) plus a final `HTTP <code>` line. Full request and
response shape: [`references/mintlify-api.md`](references/mintlify-api.md).

Search the way a user would type it — short keyword queries ("webhook
signature", "physical card activation") outperform full sentences. If the
first query misses, vary the vocabulary (e.g. `PAN` vs `card number`,
`collateral` vs `balance`) before concluding a page doesn't exist.

### 2. Verify and present the link

Convert a result's page path into a link on the live site:
`https://docs.rain.xyz/<path>` (e.g. `docs/settlement-partner-managed` →
`https://docs.rain.xyz/docs/settlement-partner-managed`). Present the page
title, the link, and a one-line reason it's the right page. When several
candidates are close — the docs often split a topic into **Rain-Managed** and
**Partner-Managed** variants — say which variant each link covers instead of
picking one silently.

### 3. Read the page content when needed

- **Search results already include page content** — often enough to answer
  directly and quote from.
- Mintlify serves every page as raw Markdown at the same URL with `.md`
  appended (`https://docs.rain.xyz/docs/settlement.md`). ⚠️ The Rain docs
  site is **login-gated**: an unauthenticated fetch may redirect to a login
  page, so treat this as best-effort.
- If the `rain-platform-docs` repo is checked out locally, `Grep` the `.mdx`
  sources and `docs.json` navigation directly — that's the same content,
  uncapped and offline.

### Fallback — no key available

Without `MINTLIFY_ASSISTANT_KEY`, don't dead-end: search a local
`rain-platform-docs` checkout with `Grep` (page paths in `docs.json` mirror
the live URL structure), or ask the user for the key. Say explicitly which
method produced the answer.

## Asking the docs assistant

For a synthesized answer grounded in the docs (rather than a list of pages):

```bash
${CLAUDE_SKILL_DIR}/scripts/ask_assistant.sh "How do I activate a physical card?"
```

This calls `POST https://api-dsc.mintlify.com/v1/assistant/{domain}/message`
and prints the streamed response, which interleaves the answer with the
retrieved documentation chunks. Prefer plain search when the user wants a
*link*; use the assistant when they want an *answer with citations*. Every
assistant call also counts toward the docs' AI-engagement analytics.

## Pulling docs stats (Coinbase-style usage report)

The Analytics export API (admin key) exports the metrics behind the Mintlify
dashboard. Map them to the headline numbers Mintlify's case studies quote:

| Report | Script argument | Case-study metric it backs |
| --- | --- | --- |
| Search queries | `search-queries` | "~24,000 searches YTD across ~10,000 users" |
| Page views | `page-views` | "3.3M+ total documentation views" |
| Unique visitors | `visitors` | unique developers reached |
| Assistant conversations | `assistant-conversations` | "8,704 AI assistant queries in 60 days" |
| Assistant caller stats | `caller-stats` | "2,736 unique developers interacting" |
| User feedback | `feedback` / `feedback-by-page` | "848 thumbs-up reactions on AI answers" |

```bash
${CLAUDE_SKILL_DIR}/scripts/docs_analytics.sh search-queries dateFrom=2026-01-01 dateTo=2026-07-21
${CLAUDE_SKILL_DIR}/scripts/docs_analytics.sh visitors limit=100 offset=0
```

Endpoints live under `GET https://api.mintlify.com/v1/analytics/{projectId}/…`
and paginate with `limit`/`offset`/`hasMore` — loop `offset += limit` while
`hasMore` is `true` before summing anything, or your totals will silently
undercount. ⚠️ Only the `visitors` path is verified verbatim in this skill;
if another report returns `404`, check the live endpoint list at
`https://mintlify.com/docs/api/introduction` before retrying — **never
brute-force path variants** (same rule as `rain-api-generic`).

When asked for "our stats like the Coinbase case study", pull each report for
the requested date range, aggregate, and present the numbers grouped the same
way: discoverability (searches, views, visitors), AI engagement (assistant
queries, unique callers), and content quality (feedback). State the date range
on every number.

## Common pitfalls

- **Wrong key for the endpoint.** Search/Assistant take the `mint_dsc_`
  assistant key; Analytics takes the `mint_` admin key. A `401` usually means
  the keys are swapped, not that the key is dead.
- **`{domain}` is the Mintlify subdomain slug, not the custom domain.** Read
  it off the dashboard URL. `docs.rain.xyz` in the path returns not-found.
- **Search results are page chunks.** Several results can point at the same
  page; de-duplicate by path before presenting "N pages found".
- **Rain-Managed vs Partner-Managed.** Many topics have one page per
  integration model. Confirm which model the user is on before linking one.
- **Analytics without a date range default to whatever the API defaults to.**
  Always pass `dateFrom`/`dateTo` explicitly when reporting numbers.
- **These APIs never touch raincards.xyz.** No Rain API key is involved
  anywhere in this skill; if you find yourself reaching for `RAIN_API_KEY`,
  you're in the wrong skill.

## See also

- [`references/mintlify-api.md`](references/mintlify-api.md) — full endpoint
  reference: URLs, request/response shapes, key management, verification notes.
- [`rain-api-generic`](../rain-api-generic/SKILL.md) — calling Rain Issuing API
  endpoints once you've found the docs for them.
- [`rain-api-auth`](../rain-api-auth/SKILL.md) — Rain API authentication (a
  frequent search destination; link its pages, don't restate them).
