# Evidence and audit boundary

Audit date: 2026-09-09 (Asia/Singapore).

## Currently verified

- The official GitHub release is `v2026.9.7`, named "Hermes Agent v0.21.1
  (v2026.9.7)". Its annotated tag peels to commit
  `2237be355906fbe6065ce1815711eee52b2d646e`.
- The tagged `pyproject.toml` reports package version `0.21.1` and pins
  `honcho-ai==2.2.0`.
- The tagged target file, MIT license, and `pyproject.toml` match the SHA256
  values recorded in `compatibility.json`.
- Honcho SDK `2.2.0` accepts message-level `metadata` and
  `configuration.reasoning.custom_instructions` in `Peer.message()`.
- The patch is regenerated from the pristine tagged target and changes only
  `plugins/memory/honcho/session.py`.
- Upstream split session auth, peer resolution, context retrieval, and migration
  into four mixins. The guard delegates retrieval to these unmodified modules
  and filters the returned derived-memory fields. Raw recent messages, observer
  routing, current-query-only semantics, and authentication errors are preserved.
- The four supporting modules are SHA256-pinned in `compatibility.json`, fetched
  from the peeled upstream commit, and used directly by behavioral tests. Status,
  install, and rollback reject missing, modified, or symlinked supporting files.
- Real upstream installation tests cover repeated install/rollback, reinstall
  from a retained backup, corrupt-backup rejection, and rejection of `0.21.0`
  even when paired with the supported target bytes.
- The installer uses POSIX `patch` when available and a checked `git apply`
  fallback otherwise. Both paths verify the exact patched output before the
  target backup or replacement is created.
- Optional user/assistant alias profiles are stored locally with `0600`
  permissions and are revalidated at runtime before entering message metadata.
  Alias values are then transmitted to the configured Honcho backend as part of
  that metadata; the setup wizard requires explicit opt-in after disclosure.
- Alias profiles in `v0.4.0` are single-user only. The wizard refuses to create
  one unless the operator confirms the Hermes instance has one human user.
- `scripts/check.sh` independently downloads the public upstream files or reads
  an explicitly supplied immutable-tag checkout, then rechecks target, license,
  and version metadata before patch replay, compilation, behavioral tests, and
  privacy scanning.
- On Docker deployments, SDK diagnostics must first import `hermes_bootstrap`.
  It activates the configured durable lazy dependency directory; a bare venv
  import can incorrectly report that the optional Honcho SDK is absent.

## Historical basis

The incident-response record preceding this package established that correct
speaker/addressee attribution was observed after adding attribution v2 guidance.
It also established that reasoning instructions alone were a soft constraint:
short-lived state and duplicate conclusions could still appear. That historical
artifact was environment-specific and was not reused as a release patch.

## Reconstruction and inference

This package is a clean reconstruction against the immutable public source, not
a byte-for-byte export of a deployed file. Runtime peer IDs replace all
deployment-specific identities. The retrieval filter is a deterministic guard
for conservative transient patterns and normalized exact duplicates.

The inference boundary is explicit: correct metadata transport is testable, but
the behavior of a remote, model-driven Honcho reasoner cannot be guaranteed by
local unit tests. Server-side conclusions should be audited separately before
claiming end-to-end correctness in a deployment.

## Public package boundary

This audit contains no server identifiers, endpoints, configuration, logs,
conversations, credentials, identity profiles, or deployment artifacts. A local
package verification does not by itself prove that any live service has loaded
the patch; deployment state must be verified separately in the target
environment.
