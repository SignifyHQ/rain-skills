# Rain Agent Skills

**Agent-native integration skills for the [Rain](https://rain.xyz) card-issuing API.**

This repo packages Rain's client-facing integration workflows as [Claude Code](https://claude.com/claude-code)
/ agent **skills** — explicit, ordered, runnable recipes that an AI coding agent (or a
developer reading over its shoulder) can follow to build a Rain integration correctly the
first time. Each skill ships real endpoint paths, real field names, SDK-first code with a
self-sufficient curl fallback, and bundled helper scripts and examples.

Rain's external clients integrate largely _through_ AI coding agents. Without packaged
guidance, agents work from raw docs and guess at endpoints, field names, and the trickier
mechanics — webhook signature verification, card-secret decryption. These skills remove that
guesswork.

---

## ⚠️ Security — read this before you start

These skills make authenticated calls to the Rain API and handle cardholder secrets. Treat
them accordingly:

- **Sandbox keys only when working with an agent.** Use your **sandbox** API key
  (`api-dev.raincards.xyz`) for all agent-assisted development. **Never paste a production
  API key into an agent prompt, chat, or any file the agent can read.**
- **Never paste decrypted card secrets** (full PAN, CVC, expiry) into an agent, a log, or a
  commit. Decryption happens locally in the bundled scripts; the plaintext must never leave
  your runtime.
- **Your API key is also your webhook signing secret.** Rain signs webhooks with HMAC-SHA256
  keyed on your **API key value**. This means the key is dual-use: leaking it both lets an
  attacker call the API _and_ forge webhooks, and **rotating the key rotates your webhook
  signing secret too.** Plan rotations with that in mind.
- Keep keys in environment variables / a secrets manager, never in source. See
  [`SECURITY.md`](./SECURITY.md) for the full policy and disclosure contact.

---

## Install

Skills install flat into `~/.agents/skills/<skill>/` via the `skills` CLI:

```bash
npx skills add <org>/rain-agent-skills --all
```

Replace `<org>` with the GitHub org/owner this repo is published under. `--all` installs
every skill in the catalog below; omit it and name a skill to install just one.

### Manual install (git clone fallback)

```bash
git clone https://github.com/<org>/rain-agent-skills.git
cp -r rain-agent-skills/skills/* ~/.agents/skills/
```

After either method, your agent discovers the skills automatically and routes to the right
one based on each skill's `description` (see [How these fit together](#how-these-fit-together)).

---

## Skill catalog

| Skill | Use when |
|-------|----------|
| [`rain-api-auth`](./skills/rain-api-auth/SKILL.md) | You're authenticating to the Rain API or setting up the SDK — `Api-Key` header, base URLs/environments, error handling, retries, idempotency, cursor pagination, and HMAC-SHA256 **webhook signature verification**. The foundation every other skill builds on. |
| [`rain-issue-consumer-card`](./skills/rain-issue-consumer-card/SKILL.md) | You're issuing a Rain consumer card end-to-end — create a KYC user application, upload compliance docs, await approval, create a virtual/physical (or agent-scoped) card, and securely retrieve + decrypt the encrypted PAN/CVC. |
| [`rain-managed-authorizations`](./skills/rain-managed-authorizations/SKILL.md) | You're receiving Rain card-spend webhooks for a **Rain-Managed** program — stand up the receiver, verify signatures, and handle the transaction lifecycle (auth, incremental, reversal, refund, settlement). Rain auto-decides; you don't approve/decline at auth time. |
| [`rain-api-generic`](./skills/rain-api-generic/SKILL.md) | You need to call a Rain endpoint **not** covered by a skill above (balances, transfers, disputes, key management, simulate endpoints). Find the endpoint in the spec first, then build the call. |
| [`rain-docs-search`](./skills/rain-docs-search/SKILL.md) | You're looking for the **right docs page** for a topic — search [docs.rain.xyz](https://docs.rain.xyz) via the Mintlify Search/Assistant APIs and cite verified links — or you want docs **usage analytics** (searches, page views, visitors, assistant queries) from the Mintlify Analytics export API. |

---

## How these fit together

- **`rain-api-auth` is the foundation.** It owns the shared building blocks — authentication,
  SDK setup, error handling, retries, idempotency, pagination, and webhook signature
  verification — that the other skills assume are already in place. Start here.
- **The two task skills** are the end-to-end flows that depend on auth being set up:
  `rain-issue-consumer-card` (get a card into a cardholder's hands) and
  `rain-managed-authorizations` (process spend on that card after it's live).
- **`rain-api-generic` is the catch-all.** When no specific skill fits, it gives the agent a
  disciplined "find the endpoint in the spec, then call it" procedure instead of guessing.
- **`rain-docs-search` finds and measures the documentation itself.** It never calls
  `raincards.xyz` — it queries the Mintlify APIs behind docs.rain.xyz to locate the right
  page to read or link, and to export docs usage stats. The other skills point at it when
  the user needs a citation rather than an API call.

The skills cross-reference each other so the agent hands off correctly — issuing a card points
to auth for SDK setup, and the authorizations skill points back to auth's signature-verification
reference rather than duplicating it.

---

## Documentation

Full Rain API reference and integration guides: **[docs.rain.xyz](https://docs.rain.xyz)**.
These skills are a companion to those docs, not a replacement — when in doubt, the live docs
and OpenAPI spec are the source of truth.

## License

[MIT](./LICENSE) — see [`CONTRIBUTING.md`](./CONTRIBUTING.md) to propose a new skill or a fix.
