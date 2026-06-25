# Security Policy

These skills make authenticated calls to the Rain card-issuing API and handle cardholder
secrets. Because they're designed to be driven by AI coding agents — which read your files,
your prompts, and your shell output — the handling rules below are not optional. Read them
before running any skill.

---

## Sandbox keys only (when working with an agent)

- Use your **sandbox** API key for all agent-assisted development. The sandbox API lives at
  `api-dev.raincards.xyz`; production lives at `api.raincards.xyz`.
- **Never paste a production API key into an agent prompt, a chat window, or any file an agent
  can read.** Agents log, summarize, and persist context; assume anything you paste is
  recoverable.
- Only switch to production keys in a controlled, non-agent runtime (your secrets manager + CI),
  and only after the integration has been validated against sandbox.

## Secret-handling rules

- **API keys live in environment variables or a secrets manager — never in source, never in a
  commit, never in an example file.** The repo `.gitignore` excludes `.env` and `.env.*`
  (except `.env.example`); keep it that way. Use `.env.example` with placeholder values only.
- **Your API key is also your webhook signing secret.** Rain signs webhooks with HMAC-SHA256
  keyed on your **API key value**. Consequences to internalize:
  - Leaking the key lets an attacker both call the API **and** forge webhooks to your endpoint.
  - **Rotating the API key rotates your webhook signing secret simultaneously** — plan rotations
    so your verifier accepts the new key (use `Secondary-Signature` during the cutover) and
    update both call paths together.
- **Never expose decrypted card secrets.** Full PAN, CVC, and expiry are decrypted **locally**
  by the bundled scripts and must never:
  - be pasted into an agent prompt or printed where an agent captures it,
  - be written to logs, error messages, analytics, or crash reports,
  - be committed to source control or stored beyond the moment of use.
  Log only non-sensitive references (e.g. `cardId`, last 4 digits if your compliance scope
  allows it).
- **Verify before you trust a webhook.** Always validate the HMAC-SHA256 `Signature` header with
  a constant-time comparison before acting on a payload. Reject unsigned or mis-signed events.
- **Use idempotency keys** on create calls and **dedupe webhooks** on the envelope `id` to avoid
  replay-driven double-processing.

## Responsible disclosure

If you discover a security vulnerability in these skills, in the bundled scripts, or in the
Rain integration patterns they document, please report it privately. **Do not open a public
issue** for a security report.

- **Contact:** security@rain.xyz _(placeholder — confirm the correct address before publishing)_
- Include: a description of the issue, affected skill/script, reproduction steps, and impact.
- We'll acknowledge receipt and work with you on a fix and coordinated disclosure timeline.

Please give us reasonable time to remediate before any public disclosure. We appreciate
good-faith research and will credit reporters who want it.
