#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACKAGE_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
COMPATIBILITY_FILE="${HAG_COMPATIBILITY_FILE:-$PACKAGE_ROOT/compatibility.json}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

apply_compatibility_patch() {
  local stage_root=$1

  if command -v patch >/dev/null 2>&1; then
    (
      cd -- "$stage_root"
      patch --batch --forward -p"$PATCH_STRIP" < "$PATCH_FILE"
    )
    return
  fi

  if command -v git >/dev/null 2>&1; then
    (
      cd -- "$stage_root"
      git apply --check -p"$PATCH_STRIP" "$PATCH_FILE"
      git apply -p"$PATCH_STRIP" "$PATCH_FILE"
    )
    return
  fi

  die "required command not found: patch or git"
}

reject_symlink_components() {
  local root=$1
  local candidate=$2
  local label=$3
  local relative cursor part
  local -a parts

  [[ "$candidate" == "$root"/* ]] || die "$label escapes its expected root"
  relative="${candidate#"$root"/}"
  cursor="$root"
  IFS='/' read -r -a parts <<< "$relative"
  for part in "${parts[@]}"; do
    cursor="$cursor/$part"
    [[ ! -L "$cursor" ]] || die "$label contains a symbolic-link component: $cursor"
  done
}

sha256_file() {
  local path=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    die "required command not found: sha256sum or shasum"
  fi
}

json_get() {
  local file=$1
  shift
  python3 - "$file" "$@" <<'PY'
import json
import sys

path = sys.argv[1]
keys = sys.argv[2:]
with open(path, encoding="utf-8") as handle:
    value = json.load(handle)
for key in keys:
    value = value[key]
if isinstance(value, (dict, list)):
    raise SystemExit("expected scalar compatibility value")
print(value)
PY
}

load_compatibility() {
  require_command python3
  [[ -f "$COMPATIBILITY_FILE" ]] || die "compatibility file not found: $COMPATIBILITY_FILE"

  PACKAGE_VERSION="$(json_get "$COMPATIBILITY_FILE" package version)"
  RELEASE_TAG="$(json_get "$COMPATIBILITY_FILE" upstream release_tag)"
  HERMES_VERSION="$(json_get "$COMPATIBILITY_FILE" upstream python_package version)"
  TARGET_REL="$(json_get "$COMPATIBILITY_FILE" target path)"
  PRISTINE_SHA256="$(json_get "$COMPATIBILITY_FILE" target pristine_sha256)"
  PATCHED_SHA256="$(json_get "$COMPATIBILITY_FILE" target patched_sha256)"
  PATCH_REL="$(json_get "$COMPATIBILITY_FILE" patch path)"
  PATCH_STRIP="$(json_get "$COMPATIBILITY_FILE" patch strip)"
  PATCH_SHA256="$(json_get "$COMPATIBILITY_FILE" patch sha256)"

  [[ "$TARGET_REL" != /* && "$TARGET_REL" != *..* ]] || die "unsafe target path in compatibility file"
  [[ "$PATCH_REL" != /* && "$PATCH_REL" != *..* ]] || die "unsafe patch path in compatibility file"
  [[ "$TARGET_REL" =~ ^[A-Za-z0-9._/-]+$ ]] || die "invalid target path in compatibility file"
  [[ "$PATCH_REL" =~ ^[A-Za-z0-9._/-]+$ ]] || die "invalid patch path in compatibility file"
  [[ "$PATCH_STRIP" =~ ^[0-9]+$ ]] || die "invalid patch strip level"
  [[ "$PRISTINE_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "invalid pristine SHA256"
  [[ "$PATCHED_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "invalid patched SHA256"
  [[ "$PATCH_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "invalid patch SHA256"

  PATCH_FILE="$PACKAGE_ROOT/$PATCH_REL"
  reject_symlink_components "$PACKAGE_ROOT" "$PATCH_FILE" "patch path"
  [[ -f "$PATCH_FILE" && ! -L "$PATCH_FILE" ]] || die "patch file is missing or unsafe: $PATCH_FILE"
  local actual_patch_sha
  actual_patch_sha="$(sha256_file "$PATCH_FILE")"
  [[ "$actual_patch_sha" == "$PATCH_SHA256" ]] || die "patch SHA256 mismatch"
}

resolve_hermes_root() {
  local requested=$1
  [[ -d "$requested" ]] || die "Hermes root is not a directory: $requested"
  HERMES_ROOT="$(cd -- "$requested" && pwd -P)"
  PYPROJECT_FILE="$HERMES_ROOT/pyproject.toml"
  TARGET_FILE="$HERMES_ROOT/$TARGET_REL"
  BACKUP_FILE="$HERMES_ROOT/.hermes-honcho-attribution-guard/backups/$RELEASE_TAG/$TARGET_REL"

  reject_symlink_components "$HERMES_ROOT" "$PYPROJECT_FILE" "pyproject path"
  reject_symlink_components "$HERMES_ROOT" "$TARGET_FILE" "target path"
  reject_symlink_components "$HERMES_ROOT" "$BACKUP_FILE" "backup path"
  [[ -f "$PYPROJECT_FILE" && ! -L "$PYPROJECT_FILE" ]] || die "missing or unsafe pyproject.toml"
  [[ -f "$TARGET_FILE" && ! -L "$TARGET_FILE" ]] || die "missing or unsafe target: $TARGET_REL"
}

read_hermes_version() {
  python3 - "$PYPROJECT_FILE" <<'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    for line in handle:
        match = re.fullmatch(r'\s*version\s*=\s*["\x27]([^"\x27]+)["\x27]\s*', line)
        if match:
            print(match.group(1))
            break
    else:
        raise SystemExit("unable to find project version")
PY
}

verify_hermes_version() {
  local actual
  actual="$(read_hermes_version)"
  [[ "$actual" == "$HERMES_VERSION" ]] || {
    die "incompatible Hermes version: expected $HERMES_VERSION for $RELEASE_TAG, found $actual"
  }
}

verify_backup() {
  [[ -f "$BACKUP_FILE" && ! -L "$BACKUP_FILE" ]] || die "backup is missing or unsafe: $BACKUP_FILE"
  local actual
  actual="$(sha256_file "$BACKUP_FILE")"
  [[ "$actual" == "$PRISTINE_SHA256" ]] || die "backup SHA256 mismatch; refusing to continue"
}
