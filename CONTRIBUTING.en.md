# Contributing

<p align="right">
  <a href="./CONTRIBUTING.md">简体中文</a> · <strong>English</strong>
</p>

Thank you for helping improve `hermes-honcho-attribution-guard`. This project is
a minimal patch package for Hermes Agent's built-in Honcho memory provider. It
is not a Hermes fork and does not contain deployment automation.

## Contribution scope

Contributions are welcome for:

- fixes to install, status, rollback, or the identity-alias wizard;
- improvements to attribution metadata, conservative filters, or tests;
- support for a new Hermes release after exact verification;
- clearer Chinese and English documentation, accessibility, or setup UX; and
- stronger path, permission, backup, checksum, or sensitive-data safeguards.

The following are intentionally out of scope:

- copying the complete Hermes source or turning this into a long-lived fork;
- automatically editing Hermes configuration, restarting services, or operating
  deployment control panels;
- fuzzy patches, broad version ranges, or bypasses for SHA256 gates;
- telemetry or collection of conversations, real peer/workspace/session IDs, or
  deployment credentials; and
- describing model-driven Honcho conclusions as deterministic or guaranteed.

## Development requirements

Development and verification use common POSIX tools and Python 3. Tests depend
only on the Python standard library and common command-line utilities. Confirm
these commands are available:

```bash
command -v python3 patch curl rg
```

All examples and fixtures must use synthetic values such as `Example User`,
`example-peer`, and `/path/to/hermes-agent`. Never commit real names, aliases,
server addresses, domains, logs, conversations, identity profiles, API keys,
tokens, cookies, `.env` files, databases, backups, or other private material.

## Change workflow

1. Read [AGENTS.md](./AGENTS.md), [AUDIT.md](./AUDIT.md), and
   [compatibility.json](./compatibility.json).
2. Keep the change minimal. The core patch must modify only
   `plugins/memory/honcho/session.py` in the target release.
3. Add or update tests for behavioral changes.
4. Keep Chinese and English documentation in sync.
5. Run full verification:

   ```bash
   ./honcho-guard verify
   ```

6. Build and inspect the local release package:

   ```bash
   ./scripts/build-release.sh
   ```

Local files under `dist/` are for review and publishing; do not commit them as
source files.

## Adding support for a Hermes release

Compatibility must be verified against an official immutable tag, never inferred
from a similar version:

1. Fetch the target, `LICENSE`, and version metadata from the official tag.
2. Record the tag commit, Hermes package version, and Honcho SDK version.
3. Record SHA256 values for the pristine target, upstream license, and
   `pyproject.toml` version metadata. Pin extracted upstream dependencies in
   `upstream.supporting_files` and load the real modules in tests.
4. Regenerate the patch from the pristine target; never reuse a fuzzy patch.
5. Verify that release's Honcho SDK message-metadata and reasoning-configuration
   contract.
6. Update `compatibility.json`, install/rollback gates, and version-rejection
   tests.
7. Verify install and rollback idempotency.
8. Review the complete patch diff and release-archive manifest.

Each Hermes release should have its own explicitly named patch file. The
installer must never make a best-effort attempt on an unknown release.

## Test expectations

Behavioral coverage must continue to include:

- user and assistant authorship;
- first-/second-person mappings in both directions;
- assistant guesses not directly becoming user facts;
- optional aliases never overriding peer IDs or message roles;
- transient and normalized-exact-duplicate filtering;
- refusal of incompatible versions, unknown targets, and invalid backups;
- idempotent installation and rollback; and
- private-profile permissions, conflicts, and symbolic-link rejection.

Tests must apply the real patch to a hash-verified copy of the official target.
Do not test a copied implementation that has drifted away from the patch.

## Pull request checklist

Before opening a PR, confirm:

- [ ] The change stays within the project's minimal scope.
- [ ] No real identity, deployment data, logs, credentials, tokens, or other
      sensitive material is included.
- [ ] Chinese and English documentation are synchronized.
- [ ] New behavior has corresponding tests.
- [ ] `./honcho-guard verify` passes.
- [ ] Patch, license, and compatibility SHA256 values still match.
- [ ] Install and rollback remain fail-closed and idempotent.
- [ ] The local release archive contains only explicitly allowlisted files.
- [ ] The PR distinguishes current verification, historical record, and inference.

Keep each PR focused on one clear problem. Do not open a public PR for a security
issue; read [SECURITY.en.md](./SECURITY.en.md) first.

## License

By contributing, you agree that your contribution will be distributed under the
project's [MIT License](./LICENSE) while preserving the Hermes Agent upstream
license and copyright notice.

---

<p align="center">
  <a href="./CONTRIBUTING.md">← 阅读中文贡献指南</a>
</p>
