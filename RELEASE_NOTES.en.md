# hermes-honcho-attribution-guard v0.1.0

<p align="right">
  <a href="./RELEASE_NOTES.md">简体中文</a> · <strong>English</strong>
</p>

> Safer identity attribution for Hermes Agent's built-in Honcho memory provider.

## Overview

`hermes-honcho-attribution-guard` is a small patch tool for Hermes Agent's
built-in Honcho memory provider. It addresses one central problem: when Honcho
derives long-term memory from user and assistant conversations, insufficient
attribution context can cause it to confuse who said what.

Typical failures include:

- assigning “I” in an assistant message to the user, or assigning “you” in a
  user message back to that same user;
- storing an assistant guess, suggestion, or role-play statement as a confirmed
  user fact;
- retaining one-off state such as “going to sleep” or “back later” as durable
  memory; and
- repeating the same content across summaries, representations, or peer cards.

The patch adds attribution v2 metadata to every user and assistant message. It
records speaker, addressee, message role, and first-/second-person mappings. It
also supplies stricter Honcho reasoning guidance so unconfirmed assistant guesses
should not become user facts. During retrieval, it conservatively filters a small
set of unmistakably transient statements and normalized exact duplicates.

The optional setup wizard can map nicknames, English names, handles, and
third-person self-references to a stable user peer while maintaining assistant
aliases separately. Aliases are structured metadata hints only; peer IDs,
message authorship, and pronoun mappings always have higher priority.

The tool does not delete or rewrite raw conversation messages. It is not a new
memory provider and not a Hermes fork. It patches only
`plugins/memory/honcho/session.py`.

## Install and roll back

This release provides two downloadable assets:

- `hermes-honcho-attribution-guard-v0.1.0.tar.gz` — the complete patch package;
- `SHA256SUMS` — the archive checksum.

Verify the download, extract it, and verify the inner file manifest:

```bash
shasum -a 256 -c SHA256SUMS
tar -xzf hermes-honcho-attribution-guard-v0.1.0.tar.gz
cd hermes-honcho-attribution-guard-v0.1.0
shasum -a 256 -c MANIFEST.sha256
```

Linux users can use `sha256sum -c`. Then run the unified setup command:

```bash
./honcho-guard setup
```

To undo the patch:

```bash
./honcho-guard rollback
```

Before writing, the installer verifies the Hermes version, target SHA256, and
patch SHA256, then retains a verifiable pristine backup. It safely refuses an
incompatible version, unknown local changes, an invalid backup, or a symbolic
link. Install and rollback are idempotent.

The tool does not alter Hermes configuration or restart a service, container, or
control panel. Restart Hermes using the deployment's existing service manager
after installation or rollback.

Identity aliases are optional and disabled by default. When enabled, the profile
is kept inside the Hermes checkout with file mode `0600`. Alias values are sent
as structured message metadata to the user's configured Honcho backend; the
wizard discloses this and asks for explicit consent before collection.

The `v0.1.0` alias profile is intended only for a single-user Hermes instance.
Multi-user gateways should skip it and continue using core attribution without
aliases.

## Compatibility

- Hermes release: `v2026.8.3`
- `hermes-agent`: `0.20.0`
- Honcho SDK: `honcho-ai==2.2.0`
- Guard package: `0.1.0`

Compatibility is enforced with exact versions and SHA256 values. The patch is
never fuzzily applied to a similar release.

## Known boundaries

Attribution metadata, compatibility checks, backups, and retrieval filtering are
deterministic. Honcho's server-side conclusions remain model-driven. Reasoning
guidance reduces misattribution risk but cannot guarantee that every derived
conclusion is correct. Duplicate filtering is limited to normalized exact
matches; it is not semantic deduplication.

Review conclusions produced by a fresh session after deployment before deciding
whether the behavior meets a particular use case.

---

<p align="center">
  <a href="./RELEASE_NOTES.md">← 阅读中文发布说明</a>
</p>
