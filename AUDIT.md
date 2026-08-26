# Evidence and audit boundary

Audit date: 2026-08-26 (Asia/Singapore).

## Currently verified

- The official GitHub release is `v2026.8.19`, named "Hermes Agent v0.20.5
  (v2026.8.19)". Its annotated tag peels to commit
  `fcbd1076a93841fa88855acce810e342a5b78101`.
- The tagged `pyproject.toml` reports package version `0.20.5` and pins
  `honcho-ai==2.2.0`.
- The tagged target file and MIT license match the SHA256 values recorded in
  `compatibility.json`.
- Honcho SDK `2.2.0` accepts message-level `metadata` and
  `configuration.reasoning.custom_instructions` in `Peer.message()`.
- The patch is regenerated from the pristine tagged target and changes only
  `plugins/memory/honcho/session.py`.
- The installer uses POSIX `patch` when available and a checked `git apply`
  fallback otherwise. Both paths verify the exact patched output before the
  target backup or replacement is created.
- Optional user/assistant alias profiles are stored locally with `0600`
  permissions and are revalidated at runtime before entering message metadata.
  Alias values are then transmitted to the configured Honcho backend as part of
  that metadata; the setup wizard requires explicit opt-in after disclosure.
- Alias profiles in `v0.2.0` are single-user only. The wizard refuses to create
  one unless the operator confirms the Hermes instance has one human user.
- `scripts/check.sh` independently downloads the public upstream files or reads
  an explicitly supplied immutable-tag checkout, then rechecks target, license,
  and version metadata before patch replay, compilation, behavioral tests, and
  privacy scanning.

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
