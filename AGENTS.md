# Repository instructions

## Scope

Maintain this repository as a minimal, public-safe patch package for the exact
Hermes release declared in `compatibility.json`. Do not turn it into a Hermes
fork or add deployment automation.

## Safety

- Never add real names, aliases, peer/workspace/session identifiers, endpoints,
  logs, conversations, configuration dumps, environment files, or credentials.
- Never copy a generated `identity.json` into the repository, tests, release
  archives, logs, or support output. Use synthetic `Example *` values in tests.
- Disclose that configured alias values are transmitted as structured message
  metadata to the user's Honcho backend; local-only storage applies to the profile
  file, not to the runtime metadata required for the feature.
- Use synthetic `example-*` identifiers and `/path/to/...` paths in all fixtures
  and documentation.
- Install and rollback scripts must fail closed on unknown versions, hashes,
  backups, symlinks, or local modifications.
- Scripts must not restart services, mutate remote systems, or change Hermes
  configuration.
- Keep `./honcho-guard` as the primary user-facing interface. New safety checks
  belong in the lower-level scripts so interactive and automated flows share the
  same fail-closed behavior.
- Stable peer IDs and message roles are authoritative. Human-readable aliases
  are optional metadata hints and must never override authorship or pronoun maps.
- Do not create remotes, publish artifacts, or change repository visibility
  without explicit maintainer authorization.
- Build local release archives only with `scripts/build-release.sh`. Its explicit
  allowlist is the release boundary; never replace it with a recursive workspace
  copy. Generated files belong under the ignored `dist/` directory.
- Keep the Chinese-primary and English documentation pairs synchronized:
  `README*`, `RELEASE_NOTES*`, `CONTRIBUTING*`, and `SECURITY*`.

## Compatibility changes

When adding support for another Hermes release:

1. Fetch the target, license, and version metadata from an official immutable
   upstream tag.
2. Record the peeled commit and SHA256 values in `compatibility.json`.
3. Regenerate the patch from the pristine target; never reuse a fuzzy patch.
4. Verify the Honcho SDK message-configuration contract for that release.
5. Add version-rejection and install/rollback idempotency coverage.
6. Run `./scripts/check.sh` and review the complete package diff.

## Test expectations

Keep tests on the Python standard library plus common POSIX tooling. Behavioral
tests must exercise the patch applied to the hash-verified upstream target, not
a copied implementation. Preserve explicit tests for attribution direction,
pronoun ownership, assistant-guess handling, transient/duplicate filtering,
compatibility rejection, and idempotent recovery.
