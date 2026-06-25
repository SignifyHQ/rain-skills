# Contributing to Rain Agent Skills

Thanks for helping make Rain integrations easier for developers and AI agents. This repo is a
collection of **agent skills** — each one a self-contained, runnable integration recipe. The
bar is high because agents follow these literally: a wrong field name or an off-by-one in a
crypto step ships straight into a client's codebase.

Before opening a PR, read [`SECURITY.md`](./SECURITY.md). **Never commit a real API key,
production endpoint secret, or any decrypted card data** — even in an example or a test
fixture.

---

## New-skill checklist

A skill lives at `skills/<skill-name>/` and is installed flat to `~/.agents/skills/<skill-name>/`.
When adding or substantially changing a skill, work through this list:

- [ ] **Folder + frontmatter `name` match.** The skill folder is `kebab-case` with the `rain-`
      prefix (e.g. `rain-issue-consumer-card`), and the `name:` in the SKILL.md YAML
      frontmatter is **identical** to the folder name.
- [ ] **`description` is a routing spec, not a blurb** (see below). This is the single most
      important field — it's how the agent decides whether to load your skill.
- [ ] **`allowed-tools` is set** and minimal: `Read, Write, Bash` for code-producing skills;
      add `Grep` only if the skill searches a spec (e.g. the generic catch-all).
- [ ] **SKILL.md is ≤ ~500 lines.** If it's longer, push detail into `references/` and link to
      it (progressive disclosure — the agent loads references on demand).
- [ ] **Any `references/*.md` over ~300 lines opens with a table of contents** so the agent can
      jump to the relevant section without reading the whole file.
- [ ] **SDK-first, curl fallback for every step.** Lead each step with the official SDK
      (TS / Go / Python). Provide a complete curl fallback — for languages with no official SDK,
      curl is a first-class path, so keep it self-sufficient, not abbreviated.
- [ ] **Cross-references use relative links** to siblings: `../rain-api-auth/SKILL.md`. Siblings
      are one directory up in both the repo `skills/` layout and the installed
      `~/.agents/skills/` layout, so the same relative path resolves in both.
- [ ] **Client-facing gotchas are stated as blockers, not footnotes.** External integrators lack
      internal context — call out gated features, defaults that must be toggled by an account
      manager, dashboard-first steps, and dual-use secrets loudly.
- [ ] **Voice matches the Rain docs:** second person, active voice, action-oriented. Endpoints,
      headers, and field names go in `backticks`.
- [ ] **Bundled scripts run.** Scripts are invoked relative to the skill dir. Smoke-test them.
      Anything cryptographic must be unit-tested against a known-good vector before merge.
- [ ] **Routing evals pass.** Add/update `evals.json` and run the routing checks (below).

---

## The description-is-a-routing-spec convention

A skill's `description` is **metadata the agent reads to route**, not marketing copy. Write it
to maximize correct routing and minimize wrong loads. Every description carries an explicit
`TRIGGER` clause and a `SKIP` clause:

- **TRIGGER …** — be "pushy" and concrete. Name the exact user intents, verbs, endpoint paths,
  headers, error codes, and SDK package names that should pull this skill in. Agents match on
  these surface forms, so list the phrasings a user would actually type.
- **SKIP …** — name the **sibling skills** that own adjacent territory, so the agent hands off
  instead of overreaching. This is what keeps the catch-all from swallowing specific tasks and
  keeps specific skills from straying out of scope.

Example shape (abbreviated):

```yaml
description: >-
  Authenticate to the Rain card-issuing API and set up the SDK.
  TRIGGER when the user calls/authenticates/sets up the Rain API, installs the Rain SDK,
  debugs 401/403 against raincards.xyz, sets the `Api-Key` header, ... or needs
  webhook signature verification.
  SKIP the end-to-end flows: card issuance + KYC → `rain-issue-consumer-card`;
  webhook receipt + transaction lifecycle → `rain-managed-authorizations`.
```

Keep TRIGGER/SKIP boundaries mutually exclusive across the catalog. When two skills could both
plausibly fire, the more specific one wins — and its sibling's SKIP clause should say so by name.

---

## Structure & progressive disclosure

```
skills/<skill-name>/
├── SKILL.md          # ≤ ~500 lines; the ordered recipe + handoffs
├── references/       # deep detail loaded on demand (TOC if > ~300 lines)
├── scripts/          # runnable helpers, invoked relative to the skill dir
└── examples/         # complete, runnable example files (incl. .env.example, curl/)
```

Put the happy-path recipe in `SKILL.md`. Push exhaustive field tables, state machines,
error-code catalogs, and crypto deep-dives into `references/` and link to them. The agent reads
`SKILL.md` first and pulls references only when it needs them — so don't inline what a reference
can hold.

---

## Routing evals

Each skill carries an `evals.json` of prompts and the skill each should route to. Include both
direct hits ("issue a Rain consumer card") and adversarial / ambiguous prompts ("call a Rain
endpoint to list balances") that probe the boundary with the catch-all and with siblings.

Run the routing checks before opening a PR and confirm every prompt routes to the intended
skill. If a prompt mis-routes, fix the `TRIGGER`/`SKIP` text — not the eval — until the 4-way
boundaries hold cleanly. Iterate descriptions until routing is clean.

---

## Submitting

1. Branch, make your change, run the evals and any script unit tests.
2. Confirm `npx skills add <path-or-org>/rain-agent-skills --all` still resolves every skill and
   that each `skills/<skill>/SKILL.md` is valid (parseable YAML frontmatter; `name` == folder).
3. Open a PR describing what changed and what you tested (sandbox runs, eval results, crypto
   vectors). Flag any new client-facing gotcha you surfaced.
