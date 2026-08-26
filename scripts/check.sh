#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACKAGE_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_command python3
require_command patch
require_command curl
require_command rg
require_command mktemp
load_compatibility

cd -- "$PACKAGE_ROOT"

required_files=(
  .github/workflows/ci.yml
  README.md
  README.en.md
  QUICKSTART.zh-CN.md
  RELEASE_NOTES.md
  RELEASE_NOTES.en.md
  CONTRIBUTING.md
  CONTRIBUTING.en.md
  SECURITY.md
  SECURITY.en.md
  LICENSE
  AGENTS.md
  assets/readme-hero.svg
  compatibility.json
  patches/hermes-2026.8.19.patch
  honcho-guard
  scripts/build-release.sh
  scripts/check.sh
  scripts/install.sh
  scripts/identity.py
  scripts/lib.sh
  scripts/rollback.sh
  scripts/setup.sh
  scripts/status.sh
  tests/test_attribution_v2.py
  examples/attribution.example.yaml
)
for path in "${required_files[@]}"; do
  [[ -f "$path" && ! -L "$path" ]] || die "required file is missing or unsafe: $path"
done

for script in honcho-guard scripts/build-release.sh scripts/check.sh scripts/install.sh scripts/rollback.sh scripts/setup.sh scripts/status.sh; do
  [[ -x "$script" ]] || die "script is not executable: $script"
  bash -n "$script"
done
bash -n scripts/lib.sh
python3 - scripts/identity.py <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    compile(handle.read(), path, "exec")
PY

python3 -m json.tool compatibility.json >/dev/null

python3 - .github/workflows/ci.yml <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    workflow = handle.read()

if "\t" in workflow:
    raise SystemExit("GitHub Actions workflow contains a tab")
if re.search(r"^\s*pull_request_target\s*:", workflow, re.MULTILINE):
    raise SystemExit("pull_request_target is forbidden for this untrusted PR workflow")
if re.search(r"^\s*[A-Za-z_-]+\s*:\s*write\s*$", workflow, re.MULTILINE):
    raise SystemExit("GitHub Actions workflow must not request write permission")
if "${{ secrets." in workflow:
    raise SystemExit("GitHub Actions workflow must not reference secrets")
if not re.search(r"^permissions:\s*\n\s+contents:\s*read\s*$", workflow, re.MULTILINE):
    raise SystemExit("GitHub Actions workflow must declare contents: read")
if "persist-credentials: false" not in workflow:
    raise SystemExit("checkout credentials must not persist")

action_references = re.findall(r"^\s*uses:\s*([^\s@]+)@([^\s#]+)", workflow, re.MULTILINE)
if not action_references:
    raise SystemExit("GitHub Actions workflow does not contain an external action")
for action, reference in action_references:
    if not re.fullmatch(r"[0-9a-f]{40}", reference):
        raise SystemExit(f"external action is not pinned to a full SHA: {action}")
PY

actual_patch_sha="$(sha256_file "$PATCH_FILE")"
[[ "$actual_patch_sha" == "$PATCH_SHA256" ]] || die "patch SHA256 mismatch"
actual_license_sha="$(sha256_file LICENSE)"
expected_license_sha="$(json_get "$COMPATIBILITY_FILE" upstream license_sha256)"
[[ "$actual_license_sha" == "$expected_license_sha" ]] || die "LICENSE differs from upstream"

stage_root="$(mktemp -d "${TMPDIR:-/tmp}/honcho-attribution-check.XXXXXX")"
cleanup() {
  case "$stage_root" in
    "${TMPDIR:-/tmp}"/honcho-attribution-check.*)
      rm -rf -- "$stage_root"
      ;;
    *)
      printf 'warning: refusing to remove unexpected temporary path: %s\n' "$stage_root" >&2
      ;;
  esac
}
trap cleanup EXIT

official_root="$stage_root/official"
mkdir -p -- "$official_root"
if [[ -n "${HERMES_UPSTREAM_ROOT:-}" && -n "${HERMES_BASELINE_FILE:-}" ]]; then
  die "set only one of HERMES_UPSTREAM_ROOT or HERMES_BASELINE_FILE"
fi

if [[ -n "${HERMES_UPSTREAM_ROOT:-}" ]]; then
  [[ -d "$HERMES_UPSTREAM_ROOT" ]] || die "HERMES_UPSTREAM_ROOT is not a directory"
  upstream_root="$(cd -- "$HERMES_UPSTREAM_ROOT" && pwd -P)"
  baseline_file="$upstream_root/$TARGET_REL"
  official_license="$upstream_root/LICENSE"
  official_pyproject="$upstream_root/pyproject.toml"
  reject_symlink_components "$upstream_root" "$baseline_file" "upstream target"
  reject_symlink_components "$upstream_root" "$official_license" "upstream license"
  reject_symlink_components "$upstream_root" "$official_pyproject" "upstream pyproject"
  [[ -f "$baseline_file" && ! -L "$baseline_file" ]] \
    || die "upstream target is missing or unsafe"
  [[ -f "$official_license" && ! -L "$official_license" ]] \
    || die "upstream LICENSE is missing or unsafe"
  [[ -f "$official_pyproject" && ! -L "$official_pyproject" ]] \
    || die "upstream pyproject.toml is missing or unsafe"
else
  baseline_file="${HERMES_BASELINE_FILE:-$official_root/session.py}"
  official_license="$official_root/LICENSE"
  official_pyproject="$official_root/pyproject.toml"
fi

if [[ -z "${HERMES_UPSTREAM_ROOT:-}" && -z "${HERMES_BASELINE_FILE:-}" ]]; then
  curl -L --fail --silent --show-error \
    -o "$baseline_file" \
    "https://raw.githubusercontent.com/NousResearch/hermes-agent/$RELEASE_TAG/$TARGET_REL"
fi
if [[ -z "${HERMES_UPSTREAM_ROOT:-}" ]]; then
  curl -L --fail --silent --show-error \
    -o "$official_license" \
    "https://raw.githubusercontent.com/NousResearch/hermes-agent/$RELEASE_TAG/LICENSE"
  curl -L --fail --silent --show-error \
    -o "$official_pyproject" \
    "https://raw.githubusercontent.com/NousResearch/hermes-agent/$RELEASE_TAG/pyproject.toml"
fi

[[ "$(sha256_file "$baseline_file")" == "$PRISTINE_SHA256" ]] || die "official target SHA256 mismatch"
[[ "$(sha256_file "$official_license")" == "$expected_license_sha" ]] || die "official LICENSE SHA256 mismatch"

official_version="$(python3 - "$official_pyproject" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
version = re.search(r'^version\s*=\s*["\x27]([^"\x27]+)["\x27]', text, re.MULTILINE)
honcho = re.search(r'^honcho\s*=\s*\["honcho-ai==([^"\x27]+)"\]', text, re.MULTILINE)
if not version or not honcho:
    raise SystemExit("unable to verify upstream version metadata")
print(f"{version.group(1)}|{honcho.group(1)}")
PY
)"
expected_sdk="$(json_get "$COMPATIBILITY_FILE" honcho_sdk version)"
[[ "$official_version" == "$HERMES_VERSION|$expected_sdk" ]] || die "official version metadata mismatch"

patched_root="$stage_root/patched"
patched_target="$patched_root/$TARGET_REL"
mkdir -p -- "$(dirname -- "$patched_target")"
cp -p -- "$baseline_file" "$patched_target"
(
  cd -- "$patched_root"
  patch --batch --forward -p"$PATCH_STRIP" < "$PATCH_FILE" >/dev/null
)
[[ "$(sha256_file "$patched_target")" == "$PATCHED_SHA256" ]] || die "patched target SHA256 mismatch"
python3 -m py_compile "$patched_target"

export HERMES_BASELINE_FILE="$baseline_file"
export PYTHONDONTWRITEBYTECODE=1
python3 -m unittest discover -s tests -v

if find . -path ./.git -prune -o -type l -print | rg -q .; then
  die "symbolic links are not allowed in the release package"
fi
if find . -path ./.git -prune -o -type f \
  \( -name '.env' -o -name '*.log' -o -name '*.sqlite*' -o -name '*.db' \
     -o -name '*.pem' -o -name '*.key' -o -name '*.bak' -o -name '*backup*' \) \
  -print | rg -q .; then
  die "credential, log, database, key, or backup-like file found"
fi

secret_pattern='-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|(?:api[_-]?key|access[_-]?token|password|cookie)[[:space:]]*[:=][[:space:]]*["\x27][^"\x27]+|(?:sk|ghp|github_pat)_[A-Za-z0-9_-]{16,}|https?://[^/@[:space:]]+:[^/@[:space:]]+@|\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b'
if rg -n -i -P --hidden -g '!.git/**' -g '!scripts/check.sh' -- "$secret_pattern" .; then
  die "potential secret or private endpoint found"
fi

info "check passed: source, license, versions, patch, tests, and privacy scan"
