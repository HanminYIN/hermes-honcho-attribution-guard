# Security Policy

<p align="right">
  <a href="./SECURITY.md">简体中文</a> · <strong>English</strong>
</p>

`hermes-honcho-attribution-guard` modifies one Python file inside a Hermes
checkout and can optionally store an identity-alias profile. Security reports
must protect reporters, deployments, and user data.

## Supported versions

| Guard version | Hermes release | Security support |
| --- | --- | --- |
| `0.2.0` | `v2026.8.19` / package `0.20.5` | Supported |
| `0.1.0` | `v2026.8.3` / package `0.20.0` | Supported |
| Other versions | Other Hermes releases | Unsupported unless explicitly listed |

[compatibility.json](./compatibility.json) is the machine-readable source of
truth for the current version; older releases retain their own compatibility
records. Forcing the patch onto an unknown version is not a supported scenario.

## Private reporting

This repository has GitHub Private Vulnerability Reporting enabled. Use
**[Report a vulnerability privately](https://github.com/HanminYIN/hermes-honcho-attribution-guard/security/advisories/new)**
to submit a report. Its contents are visible only to the reporter, maintainers,
and collaborators invited by a maintainer. This is the preferred channel.

If GitHub temporarily does not show the private reporting entry point:

1. Do not paste vulnerability details or credentials into a public issue,
   discussion, pull request, log, or screenshot.
2. Open a public issue containing no technical details or private information,
   stating only that a private security contact channel is needed.
3. Wait for a maintainer to provide a private channel before sending the report.

Never send real conversations, full configuration, `.env` files, API keys,
tokens, cookies, databases, identity profiles, server addresses, domains, real
peer/workspace/session IDs, or unsanitized logs. Use synthetic values and a
minimal reproducer. If a secret has already been exposed, revoke or rotate it at
the issuer first.

## What to include

Without exposing private data, provide:

- the guard version and exact Hermes release;
- operating system and necessary tool versions;
- the affected command or file path;
- minimal reproduction steps using synthetic data;
- expected and actual behavior;
- potential impact and known mitigations; and
- whether the issue has been disclosed elsewhere.

Do not attach an entire Hermes checkout or production backup. SHA256 values, a
sanitized minimal diff, and synthetic fixtures are normally sufficient.

## Security issue examples

Appropriate reports include, but are not limited to:

- install or rollback bypassing version, SHA256, backup, or symlink gates;
- path traversal, writes outside the target scope, or unsafe temporary files;
- weakened identity-profile permissions, cross-peer alias conflict bypasses, or
  private values entering logs or release archives;
- bypasses of `MANIFEST.sha256`, `SHA256SUMS`, or the release allowlist;
- malicious patches or unknown local modifications being installed without
  confirmation; and
- deterministic attribution metadata that contradicts the true message author.

The following are generally not vulnerabilities in this project:

- a low-quality model-generated Honcho conclusion when metadata and project
  constraints were transported correctly;
- independent vulnerabilities in Hermes, the Honcho service, or the Honcho SDK;
- failures after forcibly modifying a release absent from `compatibility.json`;
  and
- enabling the explicitly single-user alias profile on a multi-user gateway.

For an upstream Hermes or Honcho issue, follow that project's security process as
well. Do not publish details of an upstream zero-day in this repository.

## Handling and disclosure

Maintainers will make a best effort to acknowledge the report, reproduce it,
assess impact, and prepare a fix. Response and release timing depend on impact,
reproduction conditions, and upstream coordination; no fixed SLA is promised.
Published advisories should contain only necessary technical detail and must not
identify a reporter or real deployment.

Keep the report private until maintainers confirm a fix or the parties agree on
a disclosure date.

---

<p align="center">
  <a href="./SECURITY.md">← 阅读中文安全策略</a>
</p>
