# Evidence and audit boundary

Audit date: 2026-08-10 (Asia/Shanghai).

## Currently verified

- The official GitHub release is `v2026.8.3`, named "Hermes Agent v0.20.0
  (2026.8.3)", and its annotated tag resolves to commit
  `3c27eb6234bf91b8ceee9e9071591b31e9b148cb`.
- The tagged `pyproject.toml` reports package version `0.20.0` and pins
  `honcho-ai==2.2.0`.
- The tagged target file and MIT license match the SHA256 values recorded in
  `compatibility.json`.
- Honcho SDK `2.2.0` accepts message-level `metadata` and
  `configuration.reasoning.custom_instructions` in `Peer.message()`.
- Optional user/assistant alias profiles are stored locally with `0600`
  permissions and are revalidated at runtime before entering message metadata.
  Alias values are then transmitted to the configured Honcho backend as part of
  that metadata; the setup wizard requires explicit opt-in after disclosure.
- Alias profiles in `v0.1.0` are single-user only. The wizard refuses to create
  one unless the operator confirms the Hermes instance has one human user.
- `scripts/check.sh` independently downloads and rechecks the public upstream
  target, license, and version metadata before testing.

## Historical basis

The incident-response record preceding this package established that correct
speaker/addressee attribution was observed after adding attribution v2 guidance.
It also established that reasoning instructions alone were a soft constraint:
short-lived state and duplicate conclusions could still appear. The historical
artifact was environment-specific and was not reused as a release patch.

## Reconstruction and inference

This package is a clean reconstruction against the immutable public source, not
a byte-for-byte export of a deployed file. Runtime peer IDs replace all
deployment-specific identities. The retrieval filter is a new deterministic
guard for conservative transient patterns and normalized exact duplicates.

The inference boundary is explicit: correct metadata transport is testable, but
the behavior of a remote, model-driven Honcho reasoner cannot be guaranteed by
local unit tests. Server-side conclusions should be audited separately before
claiming end-to-end correctness in a deployment.

## Phase-one non-actions

No server, container, control panel, service, live configuration, remote
repository, release, or repository visibility setting was changed while
preparing this package.
