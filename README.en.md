<p align="right">
  <a href="./README.md">简体中文</a> · <strong>English</strong>
</p>

<p align="center">
  <img src="./assets/readme-hero.svg" alt="Hermes Honcho Attribution Guard: Memory that knows who said what" width="100%">
</p>

<p align="center">
  <a href="#what-it-fixes">What it fixes</a> ·
  <a href="#install-in-three-steps">Install</a> ·
  <a href="#identity-alias-wizard">Alias wizard</a> ·
  <a href="#exact-compatibility">Compatibility</a> ·
  <a href="#safe-rollback">Rollback</a> ·
  <a href="./RELEASE_NOTES.en.md">Release notes</a> ·
  <a href="./CONTRIBUTING.en.md">Contributing</a> ·
  <a href="./SECURITY.en.md">Security</a>
</p>

<p align="center">
  <code>v0.1.0</code>　<code>Hermes v2026.8.3</code>　<code>MIT</code>
</p>

`hermes-honcho-attribution-guard` is a small, verifiable, and reversible patch
tool for Hermes Agent's built-in Honcho memory provider. It adds explicit
attribution to user and assistant messages, reducing the risk that Honcho
confuses who said what while deriving long-term memory.

It is not a new memory provider and not a Hermes fork. The patch changes only
`plugins/memory/honcho/session.py`; it does not rewrite raw conversations, alter
Hermes configuration, or restart any service.

> [!IMPORTANT]
> This release supports only Hermes `v2026.8.3` (Python package `0.20.0`). The
> installer verifies the version, target-file SHA256, and patch SHA256. If any
> value differs, it exits safely without changing the target.

## What it fixes

| Common failure | Guard behavior |
| --- | --- |
| “I” and “you” are assigned to the wrong person | Adds speaker, addressee, role, and first-/second-person mappings |
| An assistant guess becomes a user fact | Marks assistant origin and unconfirmed status, then adds Honcho reasoning constraints |
| A nickname, handle, or third-person self-reference cannot be tied to a peer | Optionally maps several conversational aliases to a stable peer ID |
| A transient statement such as “going to sleep” becomes long-term memory | Conservatively filters a small set of unmistakably transient English and Chinese lines during retrieval |
| Summary, representation, or peer-card content repeats | Removes normalized exact duplicates during retrieval |

Stable peer IDs and message roles always have the highest priority. Aliases are
metadata hints for understanding content; they cannot override authorship and
are not used to resolve “I” or “you.”

## How it works

| Stage | Purpose |
| --- | --- |
| Message write | Attaches structured attribution v2 metadata without rewriting the message body |
| Identity resolution | Uses runtime peer IDs, roles, speaker/addressee, and pronoun mappings |
| Optional aliases | Maps user and assistant names to their peers and rejects conflicts |
| Honcho reasoning | Instructs the reasoner not to turn unconfirmed assistant guesses into user facts |
| Memory retrieval | Conservatively removes unmistakably transient lines and normalized exact duplicates |

## Install in three steps

### 1. Download and verify

Download both assets from [GitHub Releases](../../releases):

- `hermes-honcho-attribution-guard-v0.1.0.tar.gz`
- `SHA256SUMS`

macOS:

```bash
shasum -a 256 -c SHA256SUMS
tar -xzf hermes-honcho-attribution-guard-v0.1.0.tar.gz
cd hermes-honcho-attribution-guard-v0.1.0
shasum -a 256 -c MANIFEST.sha256
```

Linux:

```bash
sha256sum -c SHA256SUMS
tar -xzf hermes-honcho-attribution-guard-v0.1.0.tar.gz
cd hermes-honcho-attribution-guard-v0.1.0
sha256sum -c MANIFEST.sha256
```

### 2. Run the setup wizard

```bash
./honcho-guard setup
```

The wizard finds or asks for the Hermes checkout, reports compatibility, installs
after confirmation, and offers optional identity aliases. Users do not need to
apply the patch file manually.

### 3. Restart Hermes with your existing service manager

Restart Hermes using the method already established for your deployment so the
Python process loads the new code. This tool does not guess how Hermes is
deployed and never operates systemd, Docker, 1Panel, or another control panel.

> [!TIP]
> If you are unsure whether the patch is installed, run `./honcho-guard status`.
> It only reads version, target, backup, and identity-profile state.

## Identity alias wizard

The optional profile helps Honcho connect stable peer IDs to names used in the
conversation. One user may provide a primary name, nickname, English name,
handle, transliteration, or third-person self-reference. Assistant aliases are
kept in a separate set.

The wizard confirms, in order:

1. whether aliases should be enabled;
2. whether this is a single-user Hermes instance;
3. whether the privacy disclosure is accepted;
4. the user's primary and additional names;
5. the assistant's primary and additional names; and
6. whether the previewed profile should be saved.

```bash
./honcho-guard identity show
./honcho-guard identity edit
./honcho-guard identity clear
```

> [!WARNING]
> The `v0.1.0` alias profile is for single-user Hermes instances only. Skip this
> feature on a multi-user gateway. Core attribution remains available without it.

The profile is stored at
`.hermes-honcho-attribution-guard/identity.json` inside the selected Hermes
checkout, with file mode `0600` and directory mode `0700`. The file is never
included in this repository, a release archive, or logs. To make mappings useful,
alias values are sent as structured message metadata to the user's configured
Honcho backend. The wizard discloses this before collection and defaults to skip.

## Commands

| Command | Purpose |
| --- | --- |
| `./honcho-guard setup` | Interactive preflight, install, and optional aliases |
| `./honcho-guard status` | Show version, patch, backup, and profile state |
| `./honcho-guard install /path/to/hermes-agent` | Non-interactive install |
| `./honcho-guard rollback /path/to/hermes-agent` | Restore the verified backup |
| `./honcho-guard identity show` | Show the configured alias profile |
| `./honcho-guard verify` | Run maintainer source and test verification |
| `./honcho-guard version` | Show package and target Hermes versions |

Set `HAG_HERMES_ROOT=/path/to/hermes-agent` to omit the path from later commands.

## Exact compatibility

Compatibility is an exact version-and-hash contract, not a fuzzy range:

| Item | Required value |
| --- | --- |
| Hermes release | `v2026.8.3` |
| `hermes-agent` Python package | `0.20.0` |
| Upstream commit | `3c27eb6234bf91b8ceee9e9071591b31e9b148cb` |
| Honcho SDK | `honcho-ai==2.2.0` |
| Target | `plugins/memory/honcho/session.py` |
| Pristine SHA256 | `05b6b1076028d53a1010de294207ae8769c6bbd54d592c71739226f03ca58eb8` |
| Patched SHA256 | `c7b53d496756e4f716bd25339e0b8aec128dc57320d2ff3acd656ed78cf837e8` |

See [compatibility.json](./compatibility.json) for the machine-readable record.

## Safe rollback

Before installation, the exact pristine target is retained at:

```text
HERMES_ROOT/.hermes-honcho-attribution-guard/backups/v2026.8.3/plugins/memory/honcho/session.py
```

To restore it:

```bash
./honcho-guard rollback
```

Rollback requires both the exact patched target and exact pristine backup. It
refuses unknown local changes, unsafe backups, and symbolic links. Repeated
install and rollback commands are verified no-ops.

## Known boundaries

- Attribution metadata, compatibility checks, backups, and retrieval filtering
  are deterministic.
- Honcho's server-side conclusions remain model-driven. Reasoning instructions
  reduce misattribution risk but cannot prove every derived conclusion correct.
- Duplicate filtering is limited to normalized exact matches; it is not semantic
  deduplication.
- The patch does not migrate or remove existing Honcho conclusions. Review new
  memories from a fresh session after deployment.

See [AUDIT.md](./AUDIT.md) for the detailed evidence boundary.

<details>
<summary><strong>Maintainers: verify and build a release</strong></summary>

Full verification downloads the target source, `LICENSE`, and `pyproject.toml`
from the official immutable tag, validates hashes and versions, applies the patch
to a temporary copy, compiles it, runs tests, and scans for sensitive material:

```bash
./honcho-guard verify
```

GitHub Actions runs the same verification on pushes to `main`, pull requests,
and manual dispatches. CI has read-only repository permission, no release or
deployment authority, and pins external actions to full commit SHAs.

Build local release assets with:

```bash
./scripts/build-release.sh
```

The explicit allowlist produces a versioned archive, outer `SHA256SUMS`, and an
inner `MANIFEST.sha256`. Identical source files produce an identical archive hash.

</details>

## Upstream and license

This patch targets [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
release [`v2026.8.3`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.3).
Hermes Agent is distributed under the MIT License. The upstream license and
copyright notice are preserved verbatim in [LICENSE](./LICENSE).

---

<p align="center">
  <a href="./README.md">← 阅读简体中文版</a>
</p>
