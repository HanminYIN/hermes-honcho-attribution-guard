#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  printf 'Usage: %s HERMES_ROOT\n' "${0##*/}"
}

if [[ $# -ne 1 || $1 == "-h" || $1 == "--help" ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 2
fi

load_compatibility
resolve_hermes_root "$1"

actual_version="$(read_hermes_version)"
target_sha="$(sha256_file "$TARGET_FILE")"
state=unknown
next_action="Do not install or roll back until the local file is reviewed."
status_code=1

if [[ "$actual_version" != "$HERMES_VERSION" ]]; then
  version_state="incompatible; expected $HERMES_VERSION"
elif [[ "$target_sha" == "$PRISTINE_SHA256" ]]; then
  version_state=compatible
  state="ready to install"
  next_action="Run: ./honcho-guard install \"$HERMES_ROOT\""
  status_code=0
elif [[ "$target_sha" == "$PATCHED_SHA256" ]]; then
  version_state=compatible
  state=installed
  next_action="No file change is needed. Restart Hermes only if this install is not loaded yet."
  status_code=0
else
  version_state=compatible
fi

backup_state=missing
if [[ -e "$BACKUP_FILE" ]]; then
  if [[ -f "$BACKUP_FILE" && ! -L "$BACKUP_FILE" \
    && "$(sha256_file "$BACKUP_FILE")" == "$PRISTINE_SHA256" ]]; then
    backup_state=verified
  else
    backup_state=invalid
    status_code=1
    next_action="Do not continue until the backup collision is reviewed."
  fi
fi

if [[ "$state" == installed && "$backup_state" != verified ]]; then
  status_code=1
  next_action="The patch is present without a verified rollback backup; do not overwrite it."
fi

identity_state="not configured"
identity_path="$HERMES_ROOT/.hermes-honcho-attribution-guard/identity.json"
if [[ -e "$identity_path" ]]; then
  if python3 "$SCRIPT_DIR/identity.py" exists "$HERMES_ROOT" >/dev/null 2>&1; then
    identity_state=configured
  else
    identity_state=invalid
    status_code=1
    next_action="Review or clear the invalid private identity profile."
  fi
fi

printf 'Package:        %s %s\n' "$PACKAGE_VERSION" "$RELEASE_TAG"
printf 'Hermes root:    %s\n' "$HERMES_ROOT"
printf 'Hermes version: %s (%s)\n' "$actual_version" "$version_state"
printf 'Target state:   %s\n' "$state"
printf 'Target SHA256:  %s\n' "$target_sha"
printf 'Backup state:   %s\n' "$backup_state"
printf 'Identity aliases: %s\n' "$identity_state"
printf 'Next action:    %s\n' "$next_action"

exit "$status_code"
